# Resource Attribution

LOUTE ships only open/redistributable resource data. This file lists every source category,
license, and provenance per 1-5-5.md §14.5.

| Resource category | Source | License | Notes |
|---|---|---|---|
| wordlists/dns/* | SecLists-style public DNS samples | MIT | Curated open subdomain/hostname lists |
| wordlists/http/* | SecLists / ProjectDiscovery public wordlists | MIT | Web content and parameter names |
| wordlists/creds/* | SecLists / common password corpora | MIT | Common passwords and rules |
| wordlists/fuzz/* | payloadsallthethings / fuzzdb | MIT | Injection and fuzzing payloads |
| wordlists/wireless/* | Public WPA/SSID sample sets | MIT | WiFi passphrase samples |
| signatures/* | Project-maintained fingerprints | MIT | Tech/takeover/CVE/IoT signatures |
| regex/* | Project-maintained patterns | MIT | Secret and flag detectors |
| templates/* | ProjectDiscovery Nuclei-style (templates) | MIT | Detection templates |

No proprietary or license-restricted data is bundled. Wordlist files in this repository
are small open-data samples suitable for the `core` pack; larger `standard`/`full` packs
are fetched on demand with hash verification (§14.4).

Each file's exact SHA-256 is recorded in `resources/manifest.toml`.
