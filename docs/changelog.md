# Changelog

## V1.5.5
- M0: Catalog migrated to schema 2 (241 capabilities, 11 phases), full V1-V20
  validation, shell_escape declarations, reproducible migration script, 7 tests.
- M1: 6 core modules added (execution_scope, job_registry, provider_probe, cache,
  secrets, target_workspace), catalog_codegen binary generating 4 artifacts.
- M2: 14 dedicated parsers, full runtime lifecycle orchestrator, real run_capability
  path (no stub), resources tree (36 wordlists, 10 chains, schema, profiles,
  signatures, attribution), 33 Rust tests passing.
- M3: 13 Flutter operator screens, keyboard-first flow, widget tests.
- M4: 7 report formats (added Markdown, SARIF, PDF), docs, CI gates.
