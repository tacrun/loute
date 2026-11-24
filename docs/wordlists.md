# Wordlists & Resources

Layout per 1-5-5.md §14: `resources/wordlists/{dns,http,creds,fuzz,payloads,usernames,
dirs,params,cloud,mobile,wireless,ctf}/`, plus templates, signatures, regex,
baselines, heuristics, profiles, chains, schemas.

`resources/manifest.toml` records every wordlist with id, path, line/byte counts,
SHA-256, license, source and pack. `{wl:...}` references in the catalog resolve via
`core/wordlists.rs` → manifest lookup → hash verify → absolute path → argv. A missing
or hash-mismatched file is a typed `PlanError::WordlistMissing` - never a silent
empty-file run.

Packs: core (bundled, small) · standard (downloaded) · full (optional) · ctf · wireless.
`install_wordlist_pack` fetches, verifies hashes, and records provenance.

Licensing: only open/redistributable sources (SecLists, ProjectDiscovery,
payloadsallthethings, fuzzdb, commonspeak2, WPA wordlists). Attribution in
`resources/ATTRIBUTION.md`.
