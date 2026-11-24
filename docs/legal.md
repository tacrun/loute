# Legal & Authorization

LOUTE is an offensive security testing framework intended for authorized engagements,
labs, CTFs and research only.

Execution model (§5.1): unrestricted by design - no scope allowlists, no target
validation gates, no confirmation dialogs. Scope is opt-in advisory metadata that
annotates and filters the plan, never a hard wall (D1-D7). Safety is *reporting*,
not blocking: warnings surface as annotations.

Operators are solely responsible for obtaining written authorization before testing
any system they do not own. The framework records full command provenance and a
hash-chained audit log (I8) to support accountability and reporting.

Do not use this tool against systems without explicit permission.
