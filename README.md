<div align="center">
  <img src="loute/assets/icons/logo.png" width="120" alt="LOUTE Logo">
  <h1><b>L O U T E</b></h1>
  <h3>AUTONOMOUS BUG BOUNTY FRAMEWORK</h3>
  <p><b>V 1.5.5</b></p>
  <p><b>© 2026 Funbinet Inc.</b></p>
  <br>
  <a href="https://github.com/tacrun/loute">
    <img src="https://img.shields.io/badge/GitHub-tacrun%2Floute-blue?style=for-the-badge&logo=github&logoColor=%2300FF41&color=%23000000" alt="GitHub"/>
  </a>
</div>

---

## Overview

LOUTE is an autonomous bug bounty framework that organizes reconnaissance and security assessment workflows in one application. A Rust native backend performs network and system operations; a Flutter frontend provides the interface with the Midnight Hacker theme (pure black backgrounds and neon green accents).

The catalog of 241 capabilities across 11 phases is the source of truth for what the framework can run. Execution is argv-only: commands are built as argument vectors and never passed through a shell.

## Architecture

- **Native engine (Rust):** capability catalog loading, validation, dispatch, argv-only execution, parsers, job queue, artifact store, audit log, workspace and graph.
- **Frontend (Flutter and Riverpod):** operator console, capability explorer, provider health, jobs, findings, asset graph, workspaces, credential vault, payload studio, timeline, reports, tool manager and CTF challenge solving.
- **FFI bridge (flutter_rust_bridge 2.12.0):** communication between Dart and Rust. Bindings are committed, so code generation is not needed for a normal build.
- **Embedded catalog:** the capability catalog is compiled into the Rust library, so the installed application works without a source checkout.

## Prerequisites

Install these before building from source:

- **Flutter SDK**, stable channel, Dart 3.13 or newer (Flutter 3.38.4 or newer)
- **Rust toolchain**, with `cargo` and `rustc` on `PATH`

Platform-specific packages are listed in the sections below. The Rust backend compiles on Linux, Windows and Android targets.

## Build from source

Clone the repository and run the root build script. It detects the host operating system and produces the matching native package. Unsupported hosts exit with a clear message instead of a hard failure.

```bash
git clone https://github.com/tacrun/loute.git
cd loute
./build.sh
```

The script does not create branches, pull or merge. It builds directly from the checked-out `main` tree.

The generated package is written to `packaging/`. See the sections below for the exact file name and install command for each platform.

## Build and install by platform

### Arch Linux

Dependencies:

```bash
sudo pacman -S --needed flutter rust cargo gtk3 base-devel libarchive zstd
```

Build and install:

```bash
cd packaging
./build_arch.sh
sudo pacman -U loute-v1.5.5-1-x86_64.pkg.tar.zst
```

Launch from the application menu as **LOUTE**, or run `loute` in a terminal. An alternative `packaging/PKGBUILD` supports the standard `makepkg` workflow.

### Debian, Ubuntu and other dpkg-based Linux

Dependencies:

```bash
sudo apt-get install -y flutter rustc cargo dpkg-deb libgtk-3-dev
```

Build and install:

```bash
cd packaging
./build_linux_deb.sh
sudo dpkg -i loute_v1.5.5_amd64.deb
```

### Other Linux distributions

Build the native Rust library and Flutter Linux bundle directly:

```bash
cd rust && cargo build --release
cd ../loute
flutter pub get
flutter build linux --release
```

The bundle is at `loute/build/linux/x64/release/bundle` on x86_64, or `loute/build/linux/arm64/release/bundle` on aarch64. Copy `rust/target/release/libloute_core.so` into the bundle's `lib/` directory before running the `loute` executable. GTK 3 and glibc are required at runtime.

### Windows

A Windows host with Visual Studio Build Tools and Flutter Windows support is required. From a Bash shell on Windows:

```bash
cd packaging
./build_windows_exe.sh
```

Extract `packaging/loute_v1.5.5_windows.zip` and run `loute.exe`. No installer is required. Keep the Rust DLL next to the executable.

### Android

Android builds require the Android SDK and NDK. From a configured host:

```bash
cd packaging
./build_android_apk.sh
```

Install `packaging/loute_v1.5.5.apk` on the device. Enable installation from unknown sources if prompted.

If `loute/android/app/release.keystore` exists, the APK is signed with it. Otherwise the release build uses the default debug key, which is suitable for local testing but not for the Play Store.

## Supported architectures

| Platform | Architecture | Package |
| --- | --- | --- |
| Arch Linux | x86_64, aarch64 | .pkg.tar.zst |
| Debian/Ubuntu | amd64, arm64 | .deb |
| Linux (generic) | x86_64, aarch64 | release bundle |
| Windows | x86_64 | .zip |
| Android | arm64, armv7, x86_64 | .apk |

macOS and iOS are not currently packaged.

## Verify the build

```bash
bash scripts/verify.sh
```

This checks the Rust release build, catalog structure and hash parity, codegen idempotence, identity strings, version consistency and resource integrity. It does not require Flutter.

## Documentation

- `packaging/packaging.md`: build and distribution details
- `docs/architecture.md`: system architecture
- `docs/catalog.md`: capability catalog format and validation rules
- `docs/reporting.md`: report formats
- `docs/opsec.md`: OPSEC profiles
- `docs/wordlists.md`: bundled wordlists
- `docs/ctf.md`: CTF and lab usage
- `docs/legal.md`: legal notice

## License

Copyright (c) 2026 Funbinet Inc. All rights reserved.

This software is proprietary. No part of it may be reproduced, distributed or transmitted without prior written permission from Funbinet. It is provided "as is" without warranty of any kind.

## About the author

**Funbinet (Dominic Dancan)** is a computer scientist specializing in cybersecurity, focused on offensive security and automation.

- Email: funbinet@gmail.com
- GitHub: [tacrun](https://github.com/tacrun)

---

<div align="center">

**LOUTE V 1.5.5**
**© 2026 Funbinet Inc. All Rights Reserved.**

</div>
