<div align="center">
  <img src="../loute/assets/icons/logo.png" width="120" alt="LOUTE Logo">
  <h1><b>L O U C E</b></h1>
  <h3>AUTONOMOUS BUG BOUNTY FRAMEWORK</h3>
  <p><b>V 1.5.0</b></p>
  <p><b>© 2026 Funbinet Inc.</b></p>
  <br>
  <a href="https://github.com/funbinet">
    <img src="https://img.shields.io/badge/GitHub-funbinet-blue?style=for-the-badge&logo=github&logoColor=%2300FF41&color=%23000000" alt="GitHub"/>
  </a>
  <a href="https://codeberg.org/funbinet">
    <img src="https://img.shields.io/badge/Codeberg-funbinet-blue?style=for-the-badge&logo=codeberg&logoColor=%2300FF41&color=%23000000" alt="Codeberg"/>
  </a>
</div>


---

# LOUTE Packaging & Distribution Guide

This document explains how to build, modify, and troubleshoot the distribution packages for the LOUTE framework. The system is designed to be packaged as `.apk` (Android), `.deb` (Linux Debian-based), `.pkg.tar.zst` (Arch Linux), and `.exe` (Windows).

All generated packages should be named according to the system version, e.g., `loute_v1.5.0.apk` or `loute-v1.5.0-1-x86_64.pkg.tar.zst`.

---

## 1. Prerequisites
- **Flutter SDK**: Ensure you have the stable channel of Flutter installed.
- **Rust Toolchain**: `rustup`, `cargo`, and the necessary cross-compilation targets.
- **Flutter Rust Bridge (FRB)**: Used to generate the FFI bindings.

## 2. Linux (.deb)
### Creation
1. Compile the Rust backend: `cargo build --release`
2. Build the Flutter app: `flutter build linux --release`
3. Use a tool like `flutter_deb` or `dpkg-deb` to package the contents of `build/linux/x64/release/bundle`.
4. Name the output `loute_vX.X.X.deb`.

### Troubleshooting
- *Missing GLIBC*: Ensure the build machine's glibc version matches or is older than the target machines.
- *FFI Not Found*: Verify `libnative.so` is correctly placed in the `/lib` directory of the bundle.

## 3. Arch Linux (.pkg.tar.zst)
Arch does not install `.deb` packages natively. LOUTE provides a native Arch package build.

### Build & Install
1. Install build dependencies:
   ```bash
   sudo pacman -S --needed flutter rust cargo gtk3 base-devel
   ```
2. Run the Arch build script from the repository:
   ```bash
   cd packaging
   ./build_arch.sh
   ```
3. Install the generated package:
   ```bash
   sudo pacman -U loute-v1.5.0-1-x86_64.pkg.tar.zst
   ```

### After Install
- Launch from your app launcher/menu: **LOUTE**
- Or launch from terminal:
  ```bash
  loute
  ```

### PKGBUILD (Alternative)
A `packaging/PKGBUILD` is included for the standard Arch workflow. Build the Linux bundle first, then run `makepkg -f --noextract` from `packaging/`.

### Troubleshooting
- *flutter not found*: Install Flutter via Arch packages/AUR and ensure it is on `PATH`.
- *Missing GTK/glibc deps*: Install runtime deps with `sudo pacman -S gtk3 glibc`.
- *Desktop entry not showing*: Run `update-desktop-database` or log out/in; the package installs to `/usr/share/applications/loute.desktop`.

## 4. Windows (.exe)
### Creation
1. Compile Rust: `cargo build --target x86_64-pc-windows-msvc --release`
2. Build Flutter: `flutter build windows --release`
3. Use Inno Setup or a similar installer generator to package the `build\windows\runner\Release` directory.
4. Name the output `loute_vX.X.X.exe`.

### Troubleshooting
- *Visual Studio Build Tools*: Required for building the C++ runner.
- *DLL Missing*: Ensure the compiled Rust `.dll` is included alongside the Flutter `.exe`.

## 5. Android (.apk)
### Creation
1. Ensure Android NDK is installed.
2. Add Rust Android targets: `rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android`
3. Build Flutter APK: `flutter build apk --release` (this automatically triggers gradle to build the Rust library if configured correctly with `cargo-ndk`).
4. Name the output `loute_vX.X.X.apk`.

### Troubleshooting
- *Permissions*: Android restricts access to `/proc/net/tcp` and binaries like `ss`. Ensure the Rust backend uses the safe fallback paths as implemented in Phase 1.
- *NDK Version Mismatch*: Ensure your NDK version matches the one configured in `android/app/build.gradle`.

---

## Releasing
Upon successful build of the packages, they should be uploaded to the Git releases on:
- Github: `https://github.com/funbinet`
- Codeberg: `https://codeberg.org/funbinet`

---

<div align="center">

**LOUTE V 1.5.0** 
**© 2026 Funbinet Inc. All Rights Reserved.**

</div>
