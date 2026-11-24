#!/usr/bin/env bash
# LOUTE build entry point.
# Clones are built from this single script. It detects the host platform and
# runs the matching packaging script, so it never attempts a target that the
# current machine cannot produce.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGING="$ROOT/packaging"

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

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[!] Required tool not found: $1" >&2
    echo "    Install it and re-run this script." >&2
    return 1
  fi
}

echo "=========================================="
echo "        LOUTE Build (V1.5.5)              "
echo "=========================================="
echo "[*] Detected host: $(detect_os) on $(uname -m)"

require_tool flutter
require_tool cargo

case "$(detect_os)" in
  arch)
    echo "[*] Target: Arch Linux package (.pkg.tar.zst)"
    exec bash "$PACKAGING/build_arch.sh"
    ;;
  linux)
    echo "[*] Target: Linux package (DEB when dpkg-deb is available, else tar.gz)"
    exec bash "$PACKAGING/build_linux_deb.sh"
    ;;
  windows)
    echo "[*] Target: Windows release archive (.zip)"
    exec bash "$PACKAGING/build_windows_exe.sh"
    ;;
  *)
    echo "[!] Unsupported host OS for a native build: $(uname -s)" >&2
    echo "    Build on Linux (Arch or Debian based) or Windows." >&2
    echo "    For Android, run packaging/build_android_apk.sh on a host with the Android SDK." >&2
    exit 1
    ;;
esac
