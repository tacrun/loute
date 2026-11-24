# Resource Attribution

LOUTE ships only open/redistributable resource data. This file lists every source category,
license, and provenance per 1-5-5.md section 14.5.

| Resource category | Source | License | Notes |
|---|---|---|---|
| wordlists/passwords/* | SecLists (danielmiessler/SecLists) | MIT | Common credentials, leaked password samples |
| wordlists/passwords/4-digit.txt | Locally generated | MIT | Deterministic 0000-9999 numeric sequence |
| wordlists/passwords/6-digit.txt | Locally generated | MIT | Deterministic 000000-999999 numeric sequence |
| wordlists/passwords/8-digit.txt | Locally generated | MIT | Deterministic 8-digit numeric sequence |
| wordlists/users/* | SecLists (danielmiessler/SecLists) | MIT | Username and name lists |
| wordlists/usernames/* | SecLists (danielmiessler/SecLists) | MIT | Default and captured usernames |
| wordlists/dns/* | SecLists (danielmiessler/SecLists) | MIT | Subdomain and hostname discovery lists |
| wordlists/web/* | SecLists (danielmiessler/SecLists) | MIT | Web content, directories, parameters, API endpoints |
| wordlists/http/* | SecLists (danielmiessler/SecLists) | MIT | HTTP request methods |
| wordlists/dirs/* | SecLists (danielmiessler/SecLists) | MIT | Directory wordlists |
| wordlists/params/* | SecLists (danielmiessler/SecLists) | MIT | Parameter name lists |
| wordlists/wifi/* | SecLists (danielmiessler/SecLists) | MIT | WPA passphrases and SSID samples |
| wordlists/wireless/* | SecLists (danielmiessler/SecLists) | MIT | Wireless passphrases |
| wordlists/fuzz/* | SecLists (danielmiessler/SecLists) | MIT | XSS, LFI, SSRF, SSTI, injection payloads |
| wordlists/payloads/* | SecLists (danielmiessler/SecLists) | MIT | Command injection payloads |
| wordlists/rules/* | hashcat (hashcat/hashcat) | MIT | Hashcat mutation rules (best66, dive) |
| wordlists/ssh/* | SecLists (danielmiessler/SecLists) | MIT | SSH credential lists |
| wordlists/smb/* | SecLists (danielmiessler/SecLists) | MIT | SMB credential lists |
| wordlists/ad/* | SecLists (danielmiessler/SecLists) | MIT | Active Directory credential lists |
| wordlists/db/* | SecLists (danielmiessler/SecLists) | MIT | Database default credentials |
| wordlists/creds/* | SecLists (danielmiessler/SecLists) | MIT | Default credential combinations |
| wordlists/cloud/* | SecLists (danielmiessler/SecLists) | MIT | Cloud service keywords |
| wordlists/mobile/* | SecLists (danielmiessler/SecLists) | MIT | Mobile endpoint patterns |
| wordlists/ctf/* | SecLists (danielmiessler/SecLists) | MIT | CTF flag pattern samples |
| signatures/* | Project-maintained fingerprints | MIT | Tech/takeover/CVE/IoT signatures |
| regex/* | Project-maintained patterns | MIT | Secret and flag detectors |
| templates/* | ProjectDiscovery Nuclei-style (templates) | MIT | Detection templates |

No proprietary or license-restricted data is bundled. Wordlist files are fetched at build
time by scripts/fetch_wordlists.sh from the public SecLists and hashcat GitHub repositories.
The manifest is rebuilt by scripts/rebuild_manifest.py with SHA-256 hashes for integrity
verification.
