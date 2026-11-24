#!/usr/bin/env bash
# LOUTE Android APK Build Script
# Builds a release APK. Uses the configured release keystore when present,
# otherwise falls back to a debug-signed release APK so the build still works.
set -euo pipefail

VERSION="1.5.5"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/loute"

echo "=========================================="
echo "    Building LOUTE Android APK (Release)  "
echo "=========================================="

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[!] Required tool not found: $1" >&2
    exit 1
  fi
}

require_tool flutter
require_tool cargo

echo "[*] Verifying capability catalog is bundled..."
CATALOG="$APP_DIR/assets/capabilities/capabilities.toml.txt"
[ -f "$CATALOG" ] || { echo "[!] FATAL: $CATALOG is missing." >&2; exit 1; }
echo "[+] Catalog present: $(sha256sum "$CATALOG" | cut -d' ' -f1)"

echo "[*] Preparing Flutter workspace..."
cd "$APP_DIR"
flutter clean
flutter pub get

echo "[*] Building native Rust library..."
cd "$REPO_ROOT/rust"
cargo build --release

echo "[*] Compiling Flutter APK for Android..."
cd "$APP_DIR"
flutter build apk --release

cp build/app/outputs/flutter-apk/app-release.apk "$SCRIPT_DIR/loute_v${VERSION}.apk"

echo "[*] Success! APK ready at: packaging/loute_v${VERSION}.apk"
echo "=========================================="
