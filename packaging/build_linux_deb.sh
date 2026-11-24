#!/bin/bash
# LOUTE Linux DEB Build Script
# This script builds the production Linux app and packages it as a Debian (.deb) file.

set -e

VERSION="1.5.5"
APP_NAME="loute"
DEB_NAME="${APP_NAME}_v${VERSION}"

echo "=========================================="
echo "    Building LOUTE Linux DEB (Release)    "
echo "=========================================="

cd ../loute

# --- Catalog shipping gate (1-5-5.md S4): fail if the capability bible is absent ---
echo "[*] Verifying capability catalog is bundled..."
if [ ! -f "assets/capabilities/capabilities.toml.txt" ]; then
  echo "[!] FATAL: capabilities.toml.txt missing from assets — refusing to package." >&2
  exit 1
fi
echo "[+] Catalog present: $(sha256sum assets/capabilities/capabilities.toml.txt | cut -d' ' -f1)"

# Clean previous builds
echo "[*] Cleaning old builds..."
flutter clean
flutter pub get

# Ensure rust code is updated
echo "[*] Updating flutter_rust_bridge bindings..."
flutter_rust_bridge_codegen generate

echo "[*] Compiling Flutter App for Linux..."
flutter build linux --release

# Ensure Rust Library is up to date (Linux flutter build handles this via CMake, but let's be sure)
cd ../rust
cargo build --release
cd ../loute

# Package to Debian
echo "[*] Creating Debian package structure..."
DEB_DIR="../packaging/${DEB_NAME}_amd64"
mkdir -p "$DEB_DIR/DEBIAN"
mkdir -p "$DEB_DIR/usr/bin"
mkdir -p "$DEB_DIR/usr/lib/$APP_NAME"
mkdir -p "$DEB_DIR/usr/share/applications"
mkdir -p "$DEB_DIR/usr/share/icons/hicolor/128x128/apps"

# Create Control File
cat <<EOF > "$DEB_DIR/DEBIAN/control"
Package: loute
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: libc6 (>= 2.31), libgtk-3-0 (>= 3.24.0)
Maintainer: Funbinet <funbinet@gmail.com>
Description: LOUTE - Autonomous Bug Bounty Framework
 LOUTE is a production-grade autonomous bug bounty framework integrating a native Rust backend for lightning-fast network operations with a beautiful Flutter frontend.
EOF

# Copy Build Artifacts
cp -r build/linux/x64/release/bundle/* "$DEB_DIR/usr/lib/$APP_NAME/"

# Include Rust FRB shared library (not always bundled by Flutter linux build)
RUST_LIB="../rust/target/release/libloute_core.so"
if [ -f "$RUST_LIB" ]; then
  cp "$RUST_LIB" "$DEB_DIR/usr/lib/$APP_NAME/lib/"
fi

# Create Executable Wrapper
cat <<EOF > "$DEB_DIR/usr/bin/$APP_NAME"
#!/bin/bash
cd /usr/lib/$APP_NAME
export LD_LIBRARY_PATH="/usr/lib/$APP_NAME/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
exec ./$APP_NAME "\$@"
EOF
chmod +x "$DEB_DIR/usr/bin/$APP_NAME"

# Create Desktop Entry
cat <<EOF > "$DEB_DIR/usr/share/applications/$APP_NAME.desktop"
[Desktop Entry]
Name=LOUTE
Comment=Autonomous Bug Bounty Framework
Exec=/usr/bin/$APP_NAME
Icon=$APP_NAME
Terminal=false
Type=Application
Categories=Utility;Security;
EOF

# Copy Icon
if [ -f "assets/icons/logo.png" ]; then
    cp assets/icons/logo.png "$DEB_DIR/usr/share/icons/hicolor/128x128/apps/$APP_NAME.png"
fi

# Build DEB
cd ../packaging
echo "[*] Building Debian package..."
dpkg-deb --build "${DEB_NAME}_amd64"
mv "${DEB_NAME}_amd64.deb" "loute_v${VERSION}.deb"

# Clean up build dir
rm -rf "${DEB_NAME}_amd64"

echo "[*] Success! Application is ready at: packaging/loute_v${VERSION}.deb"
echo "=========================================="
