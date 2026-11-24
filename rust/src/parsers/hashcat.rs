// hashcat.rs - hashcat potfile output (§6.7). "hash:plaintext"
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    for line in raw.lines() {
        let t = line.trim();
        if t.is_empty() { continue; }
        if let Some((hash, plain)) = t.split_once(':') {
            out.assets.push(ParsedAsset {
                kind: "credential_ref".into(),
                key: hash.to_string(),
                attrs: { let mut m = BTreeMap::new(); m.insert("plaintext".into(), plain.to_string()); m },
            });
        } else {
            out.unparsed_count += 1;
        }
    }
    out
}
