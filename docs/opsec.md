# OPSEC & Stealth

LOUTE models OPSEC as plan *filtering and ranking*, never as an execution gate (D5/D7).
Profiles live in `resources/profiles/opsec/profiles.toml`.

| Profile | Semantics |
|---|---|
| ghost | R0/R1 only, passive-first, 1 concurrency/provider, 1.5x timeouts, jitter, DoT |
| stealth | adds R2, low-noise ordering, 1 req/s shaping, 20-40% jitter |
| balanced | default, all tiers, no shaping |
| aggressive | max concurrency, no delays, widest wordlists, R4 permitted |
| loud | everything, brute everything, decoy traffic |

Evasion mechanisms (§13.3): fragment/pad where supported, payload encoding,
LOLBins in generated payloads, low-signature ports, scan sequencing to avoid IDS
thresholds, split wordlists across time, varied resolver sets, passive-before-active.

Cleanup doctrine (§13.5): every mutating capability pairs a cleanup
(`persistence.persistence-teardown`, cleanup capabilities in exploitation/CTF).

Detection is a *reporting* signal (OPSEC profile changes detection counts
monotonically: ghost < stealth < balanced < aggressive), not a blocker.
