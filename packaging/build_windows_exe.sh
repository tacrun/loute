#!/usr/bin/env bash
# LOUTE Windows EXE Build Script
# Builds the production Windows app and packages it as a release archive.
# Requires a Windows host (or a configured Flutter Windows build environment).
set -euo pipefail

VERSION="1.5.5"
APP_NAME="loute"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/loute"

echo "=========================================="
echo "    Building LOUTE Windows EXE (Release)  "
echo "=========================================="

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[!] Required tool not found: $1" >&2
    exit 1
  fi
}

require_tool flutter
require_tool cargo
require_tool zip

echo "[*] Verifying capability catalog is bundled..."
CATALOG="$APP_DIR/assets/capabilities/capabilities.toml.txt"
[ -f "$CATALOG" ] || { echo "[!] FATAL: $CATALOG is missing." >&2; exit 1; }
echo "[+] Catalog present: $(sha256sum "$CATALOG" | cut -d' ' -f1)"

cd "$APP_DIR"
if [ ! -d "windows" ]; then
  echo "[*] Windows platform not initialized. Creating it now..."
  flutter create --platforms windows .
fi

echo "[*] Preparing Flutter workspace..."
flutter clean
flutter pub get

echo "[*] Building native Rust library..."
cd "$REPO_ROOT/rust"
cargo build --release

echo "[*] Compiling Flutter app for Windows..."
cd "$APP_DIR"
flutter build windows --release

PACKAGE_DIR="$SCRIPT_DIR/${APP_NAME}_windows_v${VERSION}"
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"
cp -r build/windows/runner/Release/* "$PACKAGE_DIR/"

(cd "$SCRIPT_DIR" && zip -r "${APP_NAME}_v${VERSION}_windows.zip" "${APP_NAME}_windows_v${VERSION}")
rm -rf "$PACKAGE_DIR"

echo "[*] Success! Windows build ready at: packaging/${APP_NAME}_v${VERSION}_windows.zip"
echo "=========================================="
