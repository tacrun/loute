#!/usr/bin/env bash
# Build and asset integrity verification for LOUTE.
# Checks that the source tree is internally consistent and that the Rust
# backend compiles. No test runner is involved.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAILED=0
pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILED=1; }
section() { echo ""; echo "=== $1 ==="; }

section "Rust release build"
if (cd rust && cargo build --release --quiet) >/tmp/loute_build.log 2>&1; then
  pass "cargo build --release"
else
  fail "cargo build --release"; tail -40 /tmp/loute_build.log
fi

section "Catalog structure"
CAPS=$(grep -c '^\[\[capability\]\]' capabilities.toml.txt)
S2=$(grep -c '^schema = 2' capabilities.toml.txt)
HDR=$(grep -c '^# LOUTE CAPABILITY CATALOG - schema 2' capabilities.toml.txt)
[ "$CAPS" = "241" ] && pass "241 capabilities" || fail "capability count ($CAPS)"
[ "$S2" = "241" ] && pass "all schema 2" || fail "schema 2 count ($S2)"
[ "$HDR" = "1" ] && pass "normalized header" || fail "header normalization"

section "Catalog hash parity"
H1=$(sha256sum capabilities.toml.txt | cut -d' ' -f1)
H2=$(sha256sum loute/assets/capabilities/capabilities.toml.txt | cut -d' ' -f1)
[ "$H1" = "$H2" ] && pass "root matches shipped asset" || fail "catalog hash mismatch"

section "Codegen idempotence"
BEFORE=$(sha256sum loute/lib/generated/capability_index.dart | cut -d' ' -f1)
(cd rust && cargo run --quiet --bin catalog_codegen >/dev/null 2>&1) || fail "catalog_codegen run"
AFTER=$(sha256sum loute/lib/generated/capability_index.dart | cut -d' ' -f1)
[ "$BEFORE" = "$AFTER" ] && pass "codegen produced no diff" || fail "codegen produced a diff"

section "Identity check"
ID_HITS=$(grep -rniE 'XF4K3|LOUCE|louce' \
  --include='*.dart' --include='*.rs' --include='*.yaml' --include='*.toml' \
  --include='*.sh' --include='*.md' --include='PKGBUILD' --include='*.kts' \
  . 2>/dev/null | grep -v '.git/' | grep -v '1-5-5.md' | grep -v 'plan.md' \
  | grep -v 'verify.sh' | grep -v 'docs/architecture.md' | grep -v 'docs/changelog.md' || true)
[ -z "$ID_HITS" ] && pass "no identity violations" || { fail "identity violations"; echo "$ID_HITS"; }

section "Version consistency"
for f in rust/Cargo.toml loute/pubspec.yaml loute/lib/providers/navigation_state.dart README.md packaging/PKGBUILD; do
  grep -q '1\.5\.5' "$f" && pass "$f = 1.5.5" || fail "$f version drift"
done

section "Resources"
[ -f resources/manifest.toml ] && pass "manifest present" || fail "manifest missing"
WL=$(grep -c '^\[\[wordlist\]\]' resources/manifest.toml)
[ "$WL" = "36" ] && pass "36 wordlists" || fail "wordlist count ($WL)"
CH=$(ls resources/chains/*.toml 2>/dev/null | wc -l)
[ "$CH" = "10" ] && pass "10 chains" || fail "chain count ($CH)"

echo ""
if [ "$FAILED" = "0" ]; then
  echo "ALL VERIFICATION GATES PASSED"
  exit 0
else
  echo "SOME VERIFICATION GATES FAILED"
  exit 1
fi
