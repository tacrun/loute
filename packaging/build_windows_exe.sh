#!/bin/bash
# LOUTE Windows EXE Build Script
# This script builds the production Windows app and packages it.
# NOTE: To run this successfully, you must be on a Windows host or using a configured 
# cross-compilation environment (like Wine + MinGW) for Flutter Windows builds.

set -e

VERSION="1.5.0"
APP_NAME="loute"

echo "=========================================="
echo "    Building LOUTE Windows EXE (Release)  "
echo "=========================================="

cd ../loute

# Ensure Windows platform is initialized
if [ ! -d "windows" ]; then
    echo "[*] Windows platform not initialized. Creating it now..."
    flutter create --platforms windows .
fi

# Clean previous builds
echo "[*] Cleaning old builds..."
flutter clean
flutter pub get

# Ensure rust code is updated
echo "[*] Updating flutter_rust_bridge bindings..."
flutter_rust_bridge_codegen generate

# Build Windows App
echo "[*] Compiling Flutter App for Windows..."
flutter build windows --release

# Note: The output will be in build/windows/runner/Release/
# To create a standalone installer (.exe), you typically use Inno Setup.
# We will copy the output to a packaging directory and zip it for easy distribution, 
# as creating an Inno Setup installer requires ISCC (Inno Setup Compiler) to be installed.

echo "[*] Packaging Release directory..."
PACKAGE_DIR="../packaging/${APP_NAME}_windows_v${VERSION}"
mkdir -p "$PACKAGE_DIR"

if [ -d "build/windows/runner/Release" ]; then
    cp -r build/windows/runner/Release/* "$PACKAGE_DIR/"
    cd ../packaging
    
    # We zip it as the base distribution.
    zip -r "${APP_NAME}_v${VERSION}_windows.zip" "${APP_NAME}_windows_v${VERSION}"
    
    # If ISCC is available via Wine, we could run it here.
    # For now, the executable is available in the zip file.
    
    rm -rf "${APP_NAME}_windows_v${VERSION}"
    echo "[*] Success! Windows build is ready at: packaging/${APP_NAME}_v${VERSION}_windows.zip"
else
    echo "[!] Windows build directory not found. Please ensure you are compiling on a supported environment."
fi

echo "=========================================="
