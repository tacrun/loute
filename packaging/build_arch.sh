#!/usr/bin/env bash
# LOUTE Arch Linux Package Build Script
# Builds the production Linux app and packages it as an Arch package (.pkg.tar.zst).
set -euo pipefail

VERSION="1.5.5"
PKGREL="1"
APP_NAME="loute"
ARCH="$(uname -m)"
PKGNAME="${APP_NAME}-v${VERSION}-${PKGREL}-${ARCH}.pkg.tar.zst"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/loute"
PKGDIR="$SCRIPT_DIR/.archpkg/pkg"

echo "=========================================="
echo "   Building LOUTE Arch Package (Release)  "
echo "=========================================="

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[!] Required tool not found: $1" >&2
    exit 1
  fi
}

require_tool flutter
require_tool cargo
require_tool bsdtar
require_tool zstd

# Flutter names its Linux bundle directory x64 on x86_64 and arm64 on aarch64.
case "$ARCH" in
  x86_64) FLUTTER_ARCH="x64" ;;
  aarch64|arm64) FLUTTER_ARCH="arm64" ;;
  *) FLUTTER_ARCH="$ARCH" ;;
esac

echo "[*] Verifying capability catalog is bundled..."
CATALOG="$APP_DIR/assets/capabilities/capabilities.toml.txt"
if [ ! -f "$CATALOG" ]; then
  echo "[!] FATAL: $CATALOG is missing - refusing to package." >&2
  exit 1
fi
echo "[+] Catalog present: $(sha256sum "$CATALOG" | cut -d' ' -f1)"

echo "[*] Preparing Flutter workspace..."
cd "$APP_DIR"
flutter clean
flutter pub get

echo "[*] Building native Rust library..."
cd "$REPO_ROOT/rust"
cargo build --release

echo "[*] Compiling Flutter app for Linux ($FLUTTER_ARCH)..."
cd "$APP_DIR"
flutter build linux --release

echo "[*] Staging Arch package..."
rm -rf "$SCRIPT_DIR/.archpkg"
mkdir -p "$PKGDIR/usr/bin" "$PKGDIR/usr/lib/$APP_NAME/lib" \
         "$PKGDIR/usr/share/applications" \
         "$PKGDIR/usr/share/icons/hicolor/128x128/apps"

BUNDLE_DIR="$APP_DIR/build/linux/$FLUTTER_ARCH/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
  BUNDLE_DIR="$(find "$APP_DIR/build/linux" -type d -path '*/release/bundle' 2>/dev/null | head -n1)"
fi
if [ ! -d "$BUNDLE_DIR" ]; then
  echo "[!] Linux bundle not found under $APP_DIR/build/linux" >&2
  exit 1
fi
cp -r "$BUNDLE_DIR/"* "$PKGDIR/usr/lib/$APP_NAME/"

RUST_LIB="$REPO_ROOT/rust/target/release/libloute_core.so"
if [ ! -f "$RUST_LIB" ]; then
  echo "[!] Rust library not found: $RUST_LIB" >&2
  exit 1
fi
cp "$RUST_LIB" "$PKGDIR/usr/lib/$APP_NAME/lib/"

cat > "$PKGDIR/usr/bin/$APP_NAME" <<'EOF'
#!/bin/bash
cd /usr/lib/loute
export LD_LIBRARY_PATH="/usr/lib/loute/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec ./loute "$@"
EOF
chmod 755 "$PKGDIR/usr/bin/$APP_NAME"

cat > "$PKGDIR/usr/share/applications/$APP_NAME.desktop" <<'EOF'
[Desktop Entry]
Name=LOUTE
Comment=Autonomous Bug Bounty Framework
Exec=/usr/bin/loute
Icon=loute
Terminal=false
Type=Application
Categories=Utility;Security;Network;
StartupNotify=true
EOF

if [ -f "$APP_DIR/assets/icons/logo.png" ]; then
  cp "$APP_DIR/assets/icons/logo.png" "$PKGDIR/usr/share/icons/hicolor/128x128/apps/$APP_NAME.png"
fi

find "$PKGDIR/usr/lib/$APP_NAME" -type f -name '*.so*' -exec chmod 755 {} \; 2>/dev/null || true
chmod 755 "$PKGDIR/usr/lib/$APP_NAME/$APP_NAME" 2>/dev/null || true

INSTALLED_SIZE=$(du -sk "$PKGDIR" | cut -f1)

cat > "$PKGDIR/.PKGINFO" <<EOF
pkgname = $APP_NAME
pkgbase = $APP_NAME
pkgver = $VERSION-$PKGREL
pkgdesc = LOUTE - Autonomous Bug Bounty Framework
url = https://github.com/tacrun/loute
builddate = $(date +%s)
packager = LOUTE Build <noreply@github.com>
size = $((INSTALLED_SIZE * 1024))
arch = $ARCH
license = custom:proprietary
depend = gtk3
depend = glibc
EOF

echo "[*] Generating package metadata..."
(cd "$PKGDIR" && LANG=C bsdtar -czf .MTREE --format=mtree \
  --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link' .PKGINFO usr)

echo "[*] Creating package archive..."
(cd "$PKGDIR" && LANG=C bsdtar -cf - .PKGINFO .MTREE usr | zstd -c -z -q -T0 -) > "$SCRIPT_DIR/$PKGNAME"

rm -rf "$SCRIPT_DIR/.archpkg"

if [ ! -s "$SCRIPT_DIR/$PKGNAME" ]; then
  echo "[!] Package archive was not created." >&2
  exit 1
fi

echo "[*] Success! Arch package ready at: packaging/$PKGNAME"
echo "[*] Install with: sudo pacman -U packaging/$PKGNAME"
echo "=========================================="
