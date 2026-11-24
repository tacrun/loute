<div align="center">
  <img src="../loute/assets/icons/logo.png" width="120" alt="LOUTE Logo">
  <h1><b>L O U T E</b></h1>
  <h3>AUTONOMOUS BUG BOUNTY FRAMEWORK</h3>
  <p><b>V 1.5.5</b></p>
</div>

---

# LOUTE Packaging and Distribution

This document explains how to build LOUTE packages from source. Outputs are named with the system version, for example `loute_v1.5.5.apk` or `loute-v1.5.5-1-x86_64.pkg.tar.zst`.

## 1. Prerequisites

Install the Flutter SDK (stable channel, Dart 3.13 or newer) and the Rust toolchain (`rustup`, `cargo`) before building. The Flutter Rust Bridge bindings are committed to the repository, so `flutter_rust_bridge_codegen` is not required for a normal build.

## 2. Build from a fresh clone

From the repository root:

```bash
./build.sh
```

The script detects the host operating system and runs only the matching native build. On Arch Linux it produces an Arch package. On Debian or Ubuntu it produces a DEB. On Windows it produces a release ZIP. Unsupported hosts exit with a clear message instead of a hard failure.

To build every supported target explicitly, use `packaging/build_all.sh`, which also builds only the native target and reports the others as skipped.

## 3. Arch Linux (.pkg.tar.zst)

### Build

```bash
sudo pacman -S --needed flutter rust cargo gtk3 base-devel libarchive zstd
cd packaging
./build_arch.sh
```

This produces `loute-v1.5.5-1-<arch>.pkg.tar.zst` in the `packaging` directory.

### Install

```bash
sudo pacman -U packaging/loute-v1.5.5-1-x86_64.pkg.tar.zst
```

Launch from the application menu, or run `loute` in a terminal.

### PKGBUILD alternative

A `packaging/PKGBUILD` is included for the standard Arch workflow. Build the Linux bundle first, then run `makepkg -f --noextract` from `packaging/`.

### Troubleshooting

- `flutter` not found: install Flutter from the Arch repositories or the AUR and make sure it is on `PATH`.
- `bsdtar` or `zstd` not found: install `libarchive` and `zstd`.
- Missing GTK or glibc: install runtime dependencies with `sudo pacman -S gtk3 glibc`.

## 4. Debian and Ubuntu (.deb)

### Build

```bash
sudo apt-get install -y flutter rustc cargo dpkg-deb libgtk-3-dev
cd packaging
./build_linux_deb.sh
```

The output is `packaging/loute_v1.5.5_<arch>.deb`.

### Install

```bash
sudo dpkg -i packaging/loute_v1.5.5_amd64.deb
```

### Troubleshooting

- GLIBC mismatch: build on a machine with a glibc version equal to or older than the target.
- FFI library not found: confirm `libloute_core.so` is present in `/usr/lib/loute/lib` after install.

## 5. Windows (.exe)

Flutter Windows builds require a Windows host with Visual Studio Build Tools. From a Windows shell with Bash available:

```bash
cd packaging
./build_windows_exe.sh
```

The output is `packaging/loute_v1.5.5_windows.zip`. Extract it and run `loute.exe`. No installer is required.

To produce a standalone installer, use Inno Setup with the extracted release directory.

### Troubleshooting

- Visual Studio Build Tools: required for the C++ runner.
- Missing DLL: confirm the Rust `.dll` is in the release directory next to `loute.exe`.

## 6. Android (.apk)

Android builds require the Android SDK and NDK. From a configured host:

```bash
cd packaging
./build_android_apk.sh
```

The output is `packaging/loute_v1.5.5.apk`.

If `android/app/release.keystore` is present the APK is signed with it. Otherwise the release build is signed with the default debug key, which is sufficient for local testing but not for the Play Store.

### Troubleshooting

- NDK version mismatch: align the NDK version in `android/app/build.gradle.kts` with the installed SDK.
- Permissions: Android restricts access to `/proc/net/tcp` and tools such as `ss`. The Rust backend uses safe fallback paths.

## 7. Supported architectures

| Platform | Architecture | Package |
| --- | --- | --- |
| Arch Linux | x86_64, aarch64 | .pkg.tar.zst |
| Debian/Ubuntu | amd64, arm64 | .deb |
| Windows | x86_64 | .zip |
| Android | arm64, armv7, x86_64 | .apk |

macOS and iOS are not currently packaged. Builds for those targets are not supported.

## 8. Verification

Run the build and asset integrity checks at any time:

```bash
bash scripts/verify.sh
```

This checks the Rust release build, catalog structure and hash parity, codegen idempotence, identity strings, version consistency and resource integrity.
