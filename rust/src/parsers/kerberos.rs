// kerberos.rs - Kerberos ticket / hash output (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    for line in raw.lines() {
        let t = line.trim();
        // GetUserSPNs / ASREP hash lines contain $krb5tgs$ or $krb5asrep$
        if t.contains("$krb5tgs$") || t.contains("$krb5asrep$") {
            let user = t.split(':').next().unwrap_or("unknown").to_string();
            out.findings.push(ParsedFinding {
                title: "KERBEROS HASH".into(), detail: format!("{} ({} chars)", user, t.len()),
                severity: super::severity("medium"), discriminator: user,
            });
            out.artifacts.push(ParsedArtifact { media_type: "application/x-hash".into(), content: t.to_string() });
        }
    }
    out
}
