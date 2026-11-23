#!/bin/bash
# LOUTE Android APK Build Script
# This script builds the production Android APK, signing it with the release keystore.

set -e

echo "=========================================="
echo "    Building LOUTE Android APK (Release)   "
echo "=========================================="

cd ../loute

# Clean previous builds
echo "[*] Cleaning old builds..."
flutter clean
flutter pub get

# Ensure rust code is updated
echo "[*] Updating flutter_rust_bridge bindings..."
flutter_rust_bridge_codegen generate

# Build APK (This automatically runs gradle and rust cargo-ndk compilation)
echo "[*] Compiling Flutter APK for Android..."
flutter build apk --release

# Copy to packaging directory
echo "[*] Packaging complete! Moving to outputs..."
cp build/app/outputs/flutter-apk/app-release.apk ../packaging/loute_v1.5.0.apk

echo "[*] Success! Application is ready at: packaging/loute_v1.5.0.apk"
echo "=========================================="
