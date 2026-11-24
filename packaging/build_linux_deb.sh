#!/usr/bin/env bash
# LOUTE Linux DEB Build Script
# Builds the production Linux app and packages it as a Debian (.deb) file.
set -euo pipefail

VERSION="1.5.5"
APP_NAME="loute"
DEB_NAME="${APP_NAME}_v${VERSION}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/loute"

echo "=========================================="
echo "    Building LOUTE Linux DEB (Release)    "
echo "=========================================="

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[!] Required tool not found: $1" >&2
    exit 1
  fi
}

require_tool flutter
require_tool cargo
require_tool dpkg-deb

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) DEB_ARCH="amd64"; BUNDLE_ARCH="x64" ;;
  aarch64|arm64) DEB_ARCH="arm64"; BUNDLE_ARCH="arm64" ;;
  *) echo "[!] Unsupported DEB architecture: $ARCH" >&2; exit 1 ;;
esac

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

echo "[*] Compiling Flutter app for Linux ($BUNDLE_ARCH)..."
cd "$APP_DIR"
flutter build linux --release

echo "[*] Creating Debian package structure..."
DEB_DIR="$SCRIPT_DIR/${DEB_NAME}_${DEB_ARCH}"
rm -rf "$DEB_DIR"
mkdir -p "$DEB_DIR/DEBIAN" "$DEB_DIR/usr/bin" \
         "$DEB_DIR/usr/lib/$APP_NAME/lib" \
         "$DEB_DIR/usr/share/applications" \
         "$DEB_DIR/usr/share/icons/hicolor/128x128/apps"

cat > "$DEB_DIR/DEBIAN/control" <<EOF
Package: loute
Version: $VERSION
Section: utils
Priority: optional
Architecture: $DEB_ARCH
Depends: libc6 (>= 2.31), libgtk-3-0 (>= 3.24.0)
Maintainer: LOUTE Build <noreply@github.com>
Description: LOUTE - Autonomous Bug Bounty Framework
 LOUTE integrates a native Rust backend with a Flutter frontend for
 security assessment and reconnaissance workflows.
EOF

BUNDLE_DIR="$APP_DIR/build/linux/$BUNDLE_ARCH/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
  BUNDLE_DIR="$(find "$APP_DIR/build/linux" -type d -path '*/release/bundle' 2>/dev/null | head -n1)"
fi
[ -d "$BUNDLE_DIR" ] || { echo "[!] Linux bundle not found." >&2; exit 1; }
cp -r "$BUNDLE_DIR/"* "$DEB_DIR/usr/lib/$APP_NAME/"

RUST_LIB="$REPO_ROOT/rust/target/release/libloute_core.so"
[ -f "$RUST_LIB" ] || { echo "[!] Rust library not found: $RUST_LIB" >&2; exit 1; }
cp "$RUST_LIB" "$DEB_DIR/usr/lib/$APP_NAME/lib/"

cat > "$DEB_DIR/usr/bin/$APP_NAME" <<EOF
#!/bin/bash
cd /usr/lib/$APP_NAME
export LD_LIBRARY_PATH="/usr/lib/$APP_NAME/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec ./$APP_NAME "\$@"
EOF
chmod 755 "$DEB_DIR/usr/bin/$APP_NAME"

cat > "$DEB_DIR/usr/share/applications/$APP_NAME.desktop" <<EOF
[Desktop Entry]
Name=LOUTE
Comment=Autonomous Bug Bounty Framework
Exec=/usr/bin/$APP_NAME
Icon=$APP_NAME
Terminal=false
Type=Application
Categories=Utility;Security;
EOF

[ -f "$APP_DIR/assets/icons/logo.png" ] && \
  cp "$APP_DIR/assets/icons/logo.png" "$DEB_DIR/usr/share/icons/hicolor/128x128/apps/$APP_NAME.png"

find "$DEB_DIR/usr/lib/$APP_NAME" -type f -name '*.so*' -exec chmod 755 {} \; 2>/dev/null || true
chmod 755 "$DEB_DIR/usr/lib/$APP_NAME/$APP_NAME" 2>/dev/null || true

echo "[*] Building Debian package..."
dpkg-deb --build "$DEB_DIR"
mv "$SCRIPT_DIR/${DEB_NAME}_${DEB_ARCH}.deb" "$SCRIPT_DIR/loute_v${VERSION}_${DEB_ARCH}.deb"
rm -rf "$DEB_DIR"

echo "[*] Success! Package ready at: packaging/loute_v${VERSION}_${DEB_ARCH}.deb"
echo "[*] Install with: sudo dpkg -i packaging/loute_v${VERSION}_${DEB_ARCH}.deb"
echo "=========================================="
