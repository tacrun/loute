# Capability Catalog Reference (Schema 2)

The catalog (`capabilities.toml.txt`) is the capability bible (1-5-5.md §2). It is the
single source of truth for all 241 capabilities across 11 phases. Rust is the runtime
that satisfies these contracts; Flutter consumes a generated typed index.

## Structure

```toml
schema = 2
[[capability]]
id = 'recon.subdomain-discovery'
phase = 'recon'
label = 'SUBDOMAIN DISCOVERY'
summary = '...'
risk = 'R1'          # R0 passive .. R4 destructive
noise = 'low'        # silent|low|medium|high|screaming
mitre = ['T1595','T1590']
platforms = ['linux','android','windows']
privileges = ['none']
network = true
requires = []
provides = ['asset:domain']
inputs = [ { key = 'domain', type = 'domain', required = true } ]
provider = 'subfinder'
parser = 'lines'
probe = []
timeout = 900
retry = 1
concurrency = 4
cache_ttl = 900
artifacts = ['text']
reversible = false
cleanup = ''
chains = []
opsec_safe = true
native = false
shell_escape = false
[[capability.provider]]
binary = 'subfinder'
[[capability.provider.operation]]
name = 'Passive Enumeration'
args = ['-d', '{domain}', '-silent']
output = 'lines'
network = true
```

## Field reference
See `resources/schemas/capability.schema.json` for the full machine-readable schema.
Required fields (schema 2): schema, id, phase, label, summary, inputs, provider,
args, output, risk, noise, mitre, platforms, privileges, timeout, parser.

## Adding a capability
1. Add a `[[capability]]` block with all required schema-2 fields.
2. Set `id` snake_case/dotted, ≤40 chars, unique (V1).
3. Declare every `{placeholder}` as an input or `{wl:...}` ref (V4/V5).
4. No shell metacharacters in args unless the data is pre-escaped, then set
   `shell_escape = true` (V6/I1). Execution is always `argv`-only.
5. Run `cargo run --bin catalog_codegen` to regenerate the 4 artifacts.
6. Run `cargo test` — validation V1–V20 must pass before commit.

## Validation
`catalog_validate` enforces V1–V20 (see `rust/src/core/catalog_validate.rs`).
Any failure aborts the build; release builds cannot ship an invalid catalog.

## Codegen artifacts
- `loute/lib/generated/capability_index.dart` (Flutter typed index)
- `loute/assets/capabilities/capability_index.json` (external tooling)
- `docs/mitre_coverage.md`, `docs/provider_matrix.md`
