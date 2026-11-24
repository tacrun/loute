#!/bin/bash
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
BUILDDIR="$SCRIPT_DIR/.archpkg/build"

echo "=========================================="
echo "   Building LOUTE Arch Package (Release)  "
echo "=========================================="

command -v flutter >/dev/null || { echo "[!] flutter not found in PATH"; exit 1; }
command -v cargo >/dev/null || { echo "[!] cargo/rust toolchain not found in PATH"; exit 1; }

cd "$APP_DIR"

# --- Catalog shipping gate (1-5-5.md S4): fail if the capability bible is absent ---
echo "[*] Verifying capability catalog is bundled..."
if [ ! -f "assets/capabilities/capabilities.toml.txt" ]; then
  echo "[!] FATAL: capabilities.toml.txt missing from assets — refusing to package." >&2
  exit 1
fi
echo "[+] Catalog present: $(sha256sum assets/capabilities/capabilities.toml.txt | cut -d' ' -f1)"

echo "[*] Cleaning old builds..."
flutter clean
flutter pub get

if command -v flutter_rust_bridge_codegen >/dev/null; then
  echo "[*] Updating flutter_rust_bridge bindings..."
  flutter_rust_bridge_codegen generate
else
  echo "[*] Skipping flutter_rust_bridge_codegen (not installed); using existing bindings"
fi

echo "[*] Compiling Flutter App for Linux..."
flutter build linux --release

echo "[*] Ensuring Rust library is up to date..."
cd "$REPO_ROOT/rust"
cargo build --release

echo "[*] Staging Arch package..."
rm -rf "$SCRIPT_DIR/.archpkg"
mkdir -p "$PKGDIR/usr/bin" "$PKGDIR/usr/lib/$APP_NAME" "$PKGDIR/usr/share/applications" \
         "$PKGDIR/usr/share/icons/hicolor/128x128/apps" "$BUILDDIR"

BUNDLE_DIR="$APP_DIR/build/linux/x64/release/bundle"
if [ ! -d "$BUNDLE_DIR" ]; then
  BUNDLE_DIR="$APP_DIR/build/linux/${ARCH}/release/bundle"
fi
if [ ! -d "$BUNDLE_DIR" ]; then
  BUNDLE_DIR="$(find "$APP_DIR/build/linux" -type d -path '*/release/bundle' | head -n1)"
fi
[ -d "$BUNDLE_DIR" ] || { echo "[!] Linux bundle not found under $APP_DIR/build/linux"; exit 1; }
cp -r "$BUNDLE_DIR/"* "$PKGDIR/usr/lib/$APP_NAME/"

# Include Rust FRB shared library (not always bundled by Flutter linux build)
RUST_LIB="$REPO_ROOT/rust/target/release/libloute_core.so"
if [ -f "$RUST_LIB" ]; then
  cp "$RUST_LIB" "$PKGDIR/usr/lib/$APP_NAME/lib/"
fi

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

# Ensure bundled libs/binaries are readable/executable as needed
find "$PKGDIR/usr/lib/$APP_NAME" -type f -name '*.so*' -exec chmod 755 {} \; || true
chmod 755 "$PKGDIR/usr/lib/$APP_NAME/$APP_NAME" || true

INSTALLED_SIZE=$(du -sk "$PKGDIR" | cut -f1)

cat > "$PKGDIR/.PKGINFO" <<EOF
pkgname = $APP_NAME
pkgbase = $APP_NAME
pkgver = $VERSION-$PKGREL
pkgdesc = LOUTE - Autonomous Bug Bounty Framework
url = https://github.com/funbinet
builddate = $(date +%s)
packager = Funbinet <funbinet@gmail.com>
size = $((INSTALLED_SIZE * 1024))
arch = $ARCH
license = custom:proprietary
depend = gtk3
depend = glibc
EOF

echo "[*] Generating package metadata..."
cd "$PKGDIR"
# MTREE as expected by pacman
LANG=C bsdtar -czf .MTREE --format=mtree   --options='!all,use-set,type,uid,gid,mode,time,size,md5,sha256,link'   .PKGINFO usr

echo "[*] Creating package archive..."
LANG=C bsdtar -cf - .PKGINFO .MTREE usr | zstd -c -z -q -T0 - > "$SCRIPT_DIR/$PKGNAME"

rm -rf "$SCRIPT_DIR/.archpkg"

echo "[*] Success! Arch package ready at: packaging/$PKGNAME"
echo "[*] Install with: sudo pacman -U packaging/$PKGNAME"
echo "=========================================="
