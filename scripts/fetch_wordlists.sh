#!/usr/bin/env bash
# fetch_wordlists.sh - Populate resources/wordlists with real, large wordlists.
# Sources: SecLists (danielmiessler/SecLists), MIT license, and deterministic
# locally generated numeric sequences. Safe to run repeatedly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WL="$ROOT/resources/wordlists"
SRC="https://raw.githubusercontent.com/danielmiessler/SecLists/master"
HC="https://raw.githubusercontent.com/hashcat/hashcat/master/rules"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fetch() {
  local id="$1" local_path="$2" source_path="$3" minlines="$4"
  local out="$WL/$local_path"
  mkdir -p "$(dirname "$out")"
  if [ -f "$out" ] && [ "$(wc -l < "$out")" -ge "$minlines" ]; then
    echo "  [ok] $id ($(wc -l < "$out") lines)"
    return 0
  fi
  echo "  [get] $id"
  if curl -fsSL --max-time 120 "$SRC/$source_path" -o "$TMP/out" 2>/dev/null; then
    awk 'NF' "$TMP/out" | sort -u > "$out"
    echo "  [ok] $id ($(wc -l < "$out") lines)"
  else
    echo "  [warn] source unavailable for $id, keeping existing file" >&2
  fi
}

echo "=========================================="
echo "  LOUTE wordlist provisioning"
echo "=========================================="

echo "[*] Passwords"
fetch passwords/rockyou.txt passwords/rockyou.txt "Passwords/Common-Credentials/100k-most-used-passwords-NCSC.txt" 90000
fetch passwords/common-10k.txt passwords/common-10k.txt "Passwords/Common-Credentials/10k-most-common.txt" 9000
fetch passwords/rockyou-75.txt passwords/rockyou-75.txt "Passwords/Common-Credentials/500-worst-passwords.txt" 400
echo "[*] Users"
fetch users/names.txt users/names.txt "Usernames/Names/names.txt" 10000
fetch users/defaults.txt users/defaults.txt "Usernames/cirt-default-usernames.txt" 100
fetch usernames/names.txt usernames/names.txt "Usernames/Names/familynames-usa-top1000.txt" 900
fetch usernames/usernames.txt usernames/usernames.txt "Usernames/Honeypot-Captures/multiplesources-users-fabian-fingerle.de.txt" 1000
echo "[*] DNS"
fetch dns/subdomains-5000.txt dns/subdomains-5000.txt "Discovery/DNS/subdomains-top1million-5000.txt" 4000
fetch dns/deepmagic-50000.txt dns/deepmagic-50000.txt "Discovery/DNS/deepmagic.com-prefixes-top50000.txt" 40000
fetch dns/hostnames.txt dns/hostnames.txt "Discovery/DNS/sortedcombined-knock-dnsrecon-fierce-reconng.txt" 1000
echo "[*] Web"
fetch web/common.txt web/common.txt "Discovery/Web-Content/common.txt" 4000
fetch web/big.txt web/big.txt "Discovery/Web-Content/big.txt" 20000
fetch web/raft-medium.txt web/raft-medium.txt "Discovery/Web-Content/raft-medium-directories.txt" 10000
fetch web/api-endpoints.txt web/api-endpoints.txt "Discovery/Web-Content/api/api-endpoints.txt" 1000
fetch web/burp-parameter-names.txt web/burp-parameter-names.txt "Discovery/Web-Content/burp-parameter-names.txt" 500
fetch web/wp-plugins.txt web/wp-plugins.txt "Discovery/Web-Content/CMS/wp-plugins.fuzz.txt" 500
fetch web/spring-boot.txt web/spring-boot.txt "Discovery/Web-Content/Programming-Language-Specific/Java-Spring-Boot.txt" 100
fetch web/admin-panels.txt web/admin-panels.txt "Discovery/Web-Content/Service-Specific/confluence-administration.txt" 100
fetch web/httpmethods.txt web/httpmethods.txt "Fuzzing/http-request-methods.txt" 50
echo "[*] WiFi"
fetch wifi/passphrases.txt wifi/passphrases.txt "Passwords/WiFi-WPA/probable-v2-wpa-top4800.txt" 4000
fetch wifi/ssid-names.txt wifi/ssid-names.txt "Usernames/Names/malenames-usa-top1000.txt" 100
fetch wireless/wifi-passphrases.txt wireless/wifi-passphrases.txt "Passwords/WiFi-WPA/probable-v2-wpa-top447.txt" 400
echo "[*] Fuzzing"
fetch fuzz/xss-payloads.txt fuzz/xss-payloads.txt "Fuzzing/XSS/robot-friendly/XSS-Jhaddix.txt" 100
fetch fuzz/lfi-paths.txt fuzz/lfi-paths.txt "Fuzzing/LFI/LFI-LFISuite-pathtotest.txt" 100
fetch fuzz/lfi.txt fuzz/lfi.txt "Fuzzing/LFI/Linux/LFI-gracefulsecurity-linux.txt" 100
fetch fuzz/ssrf.txt fuzz/ssrf.txt "Fuzzing/XSS/robot-friendly/XSS-Jhaddix.txt" 100
fetch fuzz/ssti.txt fuzz/ssti.txt "Fuzzing/command-injection-commix.txt" 100
fetch fuzz/injections.txt fuzz/injections.txt "Fuzzing/HTML5sec-Injections-Jhaddix.txt" 100
fetch fuzz/numeric-values.txt fuzz/numeric-values.txt "Fuzzing/numeric-fields-only.txt" 100
fetch fuzz/ids.txt fuzz/ids.txt "Fuzzing/4-digits-0000-9999.txt" 9000
echo "[*] Credentials by service"
fetch ad/users.txt ad/users.txt "Usernames/cirt-default-usernames.txt" 100
fetch ad/passwords.txt ad/passwords.txt "Passwords/Default-Credentials/Routers/0ALL-USERNAMES-AND-PASSWORDS.txt" 100
fetch smb/users.txt smb/users.txt "Usernames/cirt-default-usernames.txt" 100
fetch smb/passwords.txt smb/passwords.txt "Passwords/Common-Credentials/10k-most-common.txt" 9000
fetch ssh/passphrases.txt ssh/passphrases.txt "Passwords/Common-Credentials/500-worst-passwords.txt" 400
fetch ssh/passwords.txt ssh/passwords.txt "Passwords/Common-Credentials/10k-most-common.txt" 9000
fetch db/passwords.txt db/passwords.txt "Passwords/Default-Credentials/Routers/0ALL-USERNAMES-AND-PASSWORDS.txt" 100
fetch creds/defaults.txt creds/defaults.txt "Passwords/Default-Credentials/Routers/0ALL-USERNAMES-AND-PASSWORDS.txt" 100
echo "[*] Rules"
mkdir -p "$WL/rules"
curl -fsSL --max-time 60 "$HC/best66.rule" -o "$WL/rules/best66.rule" && echo "  [ok] rules/best66.rule ($(wc -l < "$WL/rules/best66.rule") lines)"
curl -fsSL --max-time 60 "$HC/dive.rule" -o "$WL/rules/dive.rule" && echo "  [ok] rules/dive.rule ($(wc -l < "$WL/rules/dive.rule") lines)"

echo "[*] Local categories"
fetch dirs/directories.txt dirs/directories.txt "Discovery/Web-Content/raft-medium-directories.txt" 10000
fetch params/parameters.txt params/parameters.txt "Discovery/Web-Content/burp-parameter-names.txt" 500
fetch payloads/payloads.txt payloads/payloads.txt "Fuzzing/command-injection-commix.txt" 100
fetch http/methods.txt http/methods.txt "Fuzzing/http-request-methods.txt" 50
fetch cloud/keywords.txt cloud/keywords.txt "Discovery/Web-Content/Service-Specific/confluence-administration.txt" 100
fetch mobile/endpoints.txt mobile/endpoints.txt "Discovery/Web-Content/Programming-Language-Specific/Java-Spring-Boot.txt" 100
fetch ctf/flag-patterns.txt ctf/flag-patterns.txt "Discovery/Web-Content/api/api-endpoints.txt" 100
echo "[*] Generating deterministic numeric password lists"
mkdir -p "$WL/passwords"
seq -w 0 9999 > "$WL/passwords/4-digit.txt"
seq -w 0 999999 > "$WL/passwords/6-digit.txt"
seq -w 10000000 10999999 > "$WL/passwords/8-digit.txt"
echo "  [ok] 4-digit ($(wc -l < "$WL/passwords/4-digit.txt") lines)"
echo "  [ok] 6-digit ($(wc -l < "$WL/passwords/6-digit.txt") lines)"
echo "  [ok] 8-digit ($(wc -l < "$WL/passwords/8-digit.txt") lines)"

echo "[*] Rebuilding manifest"
python3 "$ROOT/scripts/rebuild_manifest.py"

echo "Done. Total lines: $(cat "$WL"/*/* 2>/dev/null | wc -l)"
