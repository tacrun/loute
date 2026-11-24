# LOUTE V1.5.5 — Architecture

## Overview

LOUTE V1.5.5 is a bifurcated architecture:

1. **Rust Core Engine** — capability catalog, dispatcher, command runner, provider registry, job queue, artifact store, audit log, output parsers, finding normalizer, asset graph, telemetry bus, workspace manager, wordlist registry, OPSEC profiles.
2. **Flutter Frontend** — operator console with Midnight Hacker theme, capability explorer, provider health matrix, job queue, findings/evidence viewer, asset graph, reports center.
3. **FFI Bridge** — flutter_rust_bridge connects Dart to Rust.

## Runtime Layering

```
Flutter ──FRB──> api.rs ──> dispatcher ──> job_queue ──> command_runner
                                │              │              │
                          catalog_model   provider_probe   output_parser
                                │              │              │
                          catalog_validate  provider_registry  finding_normalizer
                                │                             │
                          artifact_store <──────────────  graph / workspace
                                │
                            audit_log
```

## Capability Schema

The catalog (`capabilities.toml.txt`) is the program. Schema v1 is the current catalog; schema v2 adds risk, noise, MITRE, platforms, privileges, chains, opsec_safe, reversible, and cleanup fields.

## Identity

- System identity: **LOUTE** / **loute**
- Version: **1.5.5**
- No XF4K3, xf4k3, Xf4k3, LOUCE, louce permitted anywhere.

## Invariants

| # | Invariant | Enforcement |
|---|-----------|-------------|
| I1 | No shell. Ever. | `command_runner.rs` uses `arg()` per element |
| I2 | Catalog ships with every release | `build.rs` embeds SHA-256 hash |
| I3 | Identity is LOUTE/loute | CI grep gate |
| I4 | Real recon implementations preserved | Phase 1 functions unchanged |
| I5 | One version source | `version.json` + `sync_version.dart` |
| I6 | Risk profile before UI-visible | Catalog validation |
| I7 | No scope confinement | Unrestricted execution model |
| I8 | Full command provenance | Hash-chained audit log |
