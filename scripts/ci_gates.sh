#!/usr/bin/env bash
# ci_gates.sh — CI validation gates per 1-5-5.md §18.6 and §21.2.
# Runs: cargo test, catalog validation, codegen diff, identity grep,
# version drift, resource integrity. Fails fast with a non-zero exit code.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAILED=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=1; }
section() { echo ""; echo "=== $1 ==="; }

# --- Gate 1: Rust build + tests ---
section "Gate 1: cargo test"
if (cd rust && cargo test --quiet) >/tmp/loute_cargo.log 2>&1; then
  pass "cargo test"
else
  fail "cargo test"; tail -30 /tmp/loute_cargo.log
fi

# --- Gate 2: Catalog validation (V1-V20) via integration test already in gate 1;
#     also verify schema 2 + 241 count structurally ---
section "Gate 2: catalog structure"
CAPS=$(grep -c '^\[\[capability\]\]' capabilities.toml.txt)
S2=$(grep -c '^schema = 2' capabilities.toml.txt)
HDR=$(grep -c '^# LOUTE CAPABILITY CATALOG — schema 2' capabilities.toml.txt)
[ "$CAPS" = "241" ] && pass "241 capabilities" || fail "capability count ($CAPS)"
[ "$S2" = "241" ] && pass "all schema 2" || fail "schema 2 count ($S2)"
[ "$HDR" = "1" ] && pass "normalized header" || fail "header normalization"

# --- Gate 3: codegen diff (must be clean) ---
section "Gate 3: codegen idempotence"
BEFORE=$(sha256sum loute/lib/generated/capability_index.dart | cut -d' ' -f1)
(cd rust && cargo run --quiet --bin catalog_codegen >/dev/null 2>&1) || fail "catalog_codegen run"
AFTER=$(sha256sum loute/lib/generated/capability_index.dart | cut -d' ' -f1)
[ "$BEFORE" = "$AFTER" ] && pass "codegen diff clean" || fail "codegen produced a diff"

# --- Gate 4: catalog hash parity root vs shipped asset ---
section "Gate 4: catalog hash parity"
H1=$(sha256sum capabilities.toml.txt | cut -d' ' -f1)
H2=$(sha256sum loute/assets/capabilities/capabilities.toml.txt | cut -d' ' -f1)
[ "$H1" = "$H2" ] && pass "root == asset catalog" || fail "catalog hash mismatch"

# --- Gate 5: identity grep (I3) — exclude blueprint/changelog meta references ---
section "Gate 5: identity grep"
ID_HITS=$(grep -rniE 'XF4K3|xf4k3|Xf4k3|LOUCE|louce' \
  --include='*.dart' --include='*.rs' --include='*.yaml' --include='*.toml' \
  --include='*.sh' --include='*.md' --include='PKGBUILD' --include='*.kts' \
  . 2>/dev/null | grep -v '.git/' | grep -v '1-5-5.md' | grep -v 'plan.md' \
  | grep -v 'ci_gates.sh' | grep -v 'docs/architecture.md' | grep -v 'docs/changelog.md' || true)
[ -z "$ID_HITS" ] && pass "no identity violations" || { fail "identity violations"; echo "$ID_HITS"; }

# --- Gate 6: version drift (I5) ---
section "Gate 6: version drift"
V=$(grep -o '"version": *"[^"]*"' version.json | head -1 | grep -o '1\.5\.[0-9]*')
for f in rust/Cargo.toml loute/pubspec.yaml loute/lib/providers/navigation_state.dart README.md packaging/PKGBUILD; do
  if grep -q '1\.5\.5' "$f"; then pass "$f = 1.5.5"; else fail "$f version drift"; fi
done
STALE=$(grep -rn '1\.5\.0' --include='*.dart' --include='*.rs' --include='*.yaml' --include='*.toml' --include='*.sh' --include='PKGBUILD' . 2>/dev/null | grep -v '.git/' | grep -v '1-5-5.md' | grep -v 'sync_version.dart' | grep -v 'scripts/' || true)
[ -z "$STALE" ] && pass "no stale 1.5.0" || { fail "stale 1.5.0 refs"; echo "$STALE"; }

# --- Gate 7: resource integrity ---
section "Gate 7: resources"
[ -f resources/manifest.toml ] && pass "manifest present" || fail "manifest missing"
WL=$(grep -c '^\[\[wordlist\]\]' resources/manifest.toml)
[ "$WL" = "36" ] && pass "36 wordlists" || fail "wordlist count ($WL)"
CH=$(ls resources/chains/*.toml 2>/dev/null | wc -l)
[ "$CH" = "10" ] && pass "10 chains" || fail "chain count ($CH)"

# --- Gate 8: Dart syntax parse (dart format as parser) ---
section "Gate 8: Dart syntax"
if command -v dart >/dev/null 2>&1; then
  DART_BAD=$(dart format --output=none --set-exit-if-changed $(find loute/lib loute/test -name '*.dart') >/tmp/loute_dart.log 2>&1; echo $?)
  # Note: exit 1 here means formatting changed, not a syntax error. Parse errors exit 65+.
  if [ "$DART_BAD" -ge 65 ]; then fail "Dart syntax"; tail -20 /tmp/loute_dart.log; else pass "Dart syntax OK"; fi
else
  echo "  [SKIP] dart not installed"
fi

echo ""
if [ "$FAILED" = "0" ]; then
  echo "ALL CI GATES PASSED"
  exit 0
else
  echo "SOME CI GATES FAILED"
  exit 1
fi
