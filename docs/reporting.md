# Reporting & Deliverables

Seven formats (1-5-5.md §15.1): HTML (self-contained/offline), JSON (machine),
TXT (console), Markdown (repo/PR), CSV (spreadsheet), SARIF (CI), PDF (print).
CVE text is retained for single-finding export.

Engines live in `loute/lib/engines/`; `FormatExportService.generateAllFormats`
emits all applicable formats with a standardized filename.

Every report embeds a provenance appendix: catalog SHA-256, provider versions,
byte-identical command preview, artifact hashes, and MITRE coverage. Workspaces
export as signed archives with a hash manifest.

Redaction (§15.5): credential masking, hostname masking and screenshot exclusion
toggles for client-facing output. Secrets in env are `Redacted<T>` - logs render
`***`, audit stores fingerprints only.
