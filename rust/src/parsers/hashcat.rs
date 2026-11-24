// hashcat.rs — hashcat potfile output (§6.7). "hash:plaintext"
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

#[cfg(test)] mod tests {
    use super::*;
    #[test] fn parses_potfile() {
        let o = parse("5d41402abc4b2a76b9719d911017c592:hello\n");
        assert_eq!(o.assets.len(), 1);
        assert_eq!(o.assets[0].attrs["plaintext"], "hello");
    }
}
