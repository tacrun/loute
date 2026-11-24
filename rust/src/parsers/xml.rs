// xml.rs - minimal XML tag/attribute extraction (§6.7). No external XML crate needed.
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    // Extract elements with a <host> or <address> tag as assets.
    for tag in ["host", "address", "ip", "url", "domain"] {
        let open = format!("<{}", tag);
        let mut rest = raw;
        while let Some(pos) = rest.find(&open) {
            let after = &rest[pos + open.len()..];
            if let Some(gt) = after.find('>') {
                let inner_start = pos + open.len() + gt + 1;
                let close = format!("</{}>", tag);
                if let Some(end) = raw[inner_start..].find(&close) {
                    let value = raw[inner_start..inner_start + end].trim();
                    if !value.is_empty() {
                        out.assets.push(ParsedAsset { kind: tag.into(), key: value.to_string(), attrs: BTreeMap::new() });
                    }
                    rest = &raw[inner_start + end + close.len()..];
                    continue;
                }
            }
            break;
        }
    }
    if out.assets.is_empty() { out.artifacts.push(ParsedArtifact { media_type: "application/xml".into(), content: raw.to_string() }); }
    out
}
