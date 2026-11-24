#!/usr/bin/env bash
# LOUTE platform-aware build driver.
# Builds only the target that matches the current host and reports every other
# target as skipped. This avoids the hard failures seen when a single machine
# tried to produce Android, DEB, Windows and Arch artifacts at once.
set -euo pipefail

cd "$(dirname "$0")"

echo "=========================================="
echo "    LOUTE Multi-Platform Build Driver     "
echo "=========================================="

detect_os() {
  case "$(uname -s)" in
    Linux)
      if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
          arch|manjaro|artix|endeavouros) echo arch ;;
          *) echo linux ;;
        esac
      else
        echo linux
      fi
      ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) echo unknown ;;
  esac
}

OS="$(detect_os)"
echo "[*] Host: $OS ($(uname -m))"

skip() { echo "[SKIP] $1 on this host ($OS)."; }

case "$OS" in
  arch)
    bash ./build_arch.sh
    skip "DEB build (Arch is the native target)"
    skip "Windows EXE build"
    skip "Android APK build"
    ;;
  linux)
    bash ./build_linux_deb.sh
    skip "Arch package build"
    skip "Windows EXE build"
    skip "Android APK build"
    ;;
  windows)
    bash ./build_windows_exe.sh
    skip "DEB build"
    skip "Arch package build"
    skip "Android APK build"
    ;;
  *)
    skip "all native builds"
    echo "[!] Run the Android script on a host with the Android SDK configured."
    ;;
esac

echo "=========================================="
echo "    Build driver finished                 "
echo "=========================================="
