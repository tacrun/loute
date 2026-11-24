<div align="center">
  <img src="loute/assets/icons/logo.png" width="120" alt="LOUTE Logo">
  <h1><b>L O U T E</b></h1>
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

## Overview

LOUTE is a modern, production-grade **Autonomous Bug Bounty Framework** that orchestrates complex reconnaissance and security assessment workflows. Built with a lightning-fast Rust native backend and a cross-platform Flutter frontend (Midnight Hacker Theme UI), LOUTE provides a unified interface for conducting comprehensive security assessments.

LOUTE solves the problem of fragmented tools in bug bounty hunting by providing a single, integrated platform that handles the entire offensive security lifecycle—from initial reconnaissance to report generation.

## Core Purpose

LOUTE addresses the fundamental challenges in modern bug bounty and penetration testing:
- **Tool Fragmentation:** Eliminates the need to switch between dozens of CLI tools and interfaces.
- **Workflow Automation:** Handles asynchronous, multi-threaded operations automatically.
- **Reporting Complexity:** Dynamically generates pristine HTML, JSON, CSV, and TXT reports with a unified aesthetic.
- **Cross-Platform Delivery:** Runs natively on Linux, Windows, and Android.

## Architecture

LOUTE operates on a high-performance bifurcated architecture:
1. **The Native Engine (Rust & Tokio):** Handles network requests, concurrent execution, system-level interactions, and heavy data processing. It is designed for memory safety and zero-cost abstractions.
2. **The Frontend Engine (Flutter & Riverpod):** Delivers a state-of-the-art responsive UI dynamically scaling from desktop to mobile interfaces, maintaining a strict pure black (`#000000`) and neon green (`#00FF41`) aesthetic.
3. **The FFI Bridge (flutter_rust_bridge):** Facilitates seamless, high-speed communication between Dart and Rust.

## Phases & Capabilities

LOUTE organizes offensive operations into logical phases. Phase 1 is currently active:

### Phase 1: Reconnaissance (Information Gathering)
Purpose: Gather intelligence about target infrastructure without direct exploitation.
Capabilities:
- **DNS Bruteforce:** Multi-threaded sub-domain discovery.
- **Certificate Transparency Logs:** Extracts hostnames from `crt.sh`.
- **Cloud Provider Check:** Identifies whether targets are hosted on AWS, GCP, Azure, or Cloudflare.
- **Wayback Machine Archives:** Retrieves historical endpoints and parameters.
- **Port Scanning:** Asynchronous port discovery.
- **WAF Detection:** Fingerprints Web Application Firewalls.
- **Tech Stack Identification:** Identifies frameworks and backend languages.
- **Directory Bruteforce:** Discovers hidden paths and administrative panels.

## Installation & Startup

LOUTE is distributed as pre-compiled binaries for your target environment.

### Linux (Debian/Ubuntu - .deb)
1. Download the `loute_v1.5.0.deb` package from the Releases page.
2. Install via dpkg: `sudo dpkg -i loute_v1.5.0.deb`
3. Launch from your application menu or run `loute` in the terminal.

### Linux (Arch - .pkg.tar.zst)
1. Install build dependencies: `sudo pacman -S --needed flutter rust cargo gtk3 base-devel`
2. Build the package: `cd packaging && ./build_arch.sh`
3. Install: `sudo pacman -U packaging/loute-v1.5.0-1-x86_64.pkg.tar.zst`
4. Launch from your app launcher as **LOUTE**, or run `loute` in the terminal.

### Android (.apk)
1. Download the `loute_v1.5.0.apk` package to your Android device.
2. Ensure "Install from Unknown Sources" is enabled.
3. Tap the APK to install.
4. Launch LOUTE from your app drawer. (Note: Ensure the app has network and storage permissions).

### Windows (.exe)
1. Download the `loute_v1.5.0_windows.zip` package.
2. Extract the contents to your preferred directory.
3. Run `loute.exe`. No installation required.

## Building from Source

```bash
# Run Linux desktop mode
cd loute
flutter run -d linux

# Check Rust backend
cd rust
cargo check
```

## Proprietary Software License

Copyright (c) 2026 Funbinet Inc.
All rights reserved.

This software is the property of Funbinet and is protected by copyright laws and international copyright treaties. No part of this software may be reproduced, distributed, or transmitted in any form or by any means, without the prior written permission of Funbinet.

### Restrictions:
1. **No Redistribution:** You may not redistribute this software to any third party.
2. **No Modification:** You may not modify, adapt, reverse engineer, or disassemble this software.
3. **No Commercial Use:** You may not use this software for commercial purposes.

### Disclaimer:
This software is provided "as is" without warranty of any kind. Funbinet shall not be liable for any damages arising from the use of this software.

## About the Author

**Funbinet (Dominic Dancan)** is a Computer Scientist specializing in Cybersecurity, focusing on the intersection of offensive security and automation. He develops custom toolsets and frameworks designed to streamline reconnaissance, vulnerability assessment, and post-exploitation workflows.

- **Email:** funbinet@gmail.com
- **Codeberg:** [https://codeberg.org/funbinet](https://codeberg.org/funbinet)
- **GitHub:** [https://github.com/funbinet](https://github.com/funbinet)

---

<div align="center">

**LOUTE V 1.5.0** 
**© 2026 Funbinet Inc. All Rights Reserved.**

</div>
