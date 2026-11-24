// ldap.rs - LDAP query output (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    let mut current_dn = String::new();
    for line in raw.lines() {
        let t = line.trim();
        if let Some(dn) = t.strip_prefix("dn:") {
            current_dn = dn.trim().to_string();
            out.assets.push(ParsedAsset { kind: "ad_object".into(), key: current_dn.clone(), attrs: BTreeMap::new() });
        } else if let Some((k, v)) = t.split_once(':') {
            if !current_dn.is_empty() && !k.is_empty() {
                // Attach attribute to the most recent asset.
                if let Some(last) = out.assets.last_mut() {
                    last.attrs.insert(k.trim().to_string(), v.trim().to_string());
                }
            }
        }
    }
    out
}
