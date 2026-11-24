// lines.rs - one asset candidate per non-empty line (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    for line in raw.lines() {
        let t = line.trim();
        if t.is_empty() || t.starts_with('#') { continue; }
        let kind = if looks_like_url(t) { "url" }
            else if looks_like_ip(t) { "ip" }
            else if looks_like_domain(t) { "subdomain" }
            else { "text" };
        if kind == "text" {
            out.unparsed_count += 1;
            out.artifacts.push(ParsedArtifact { media_type: "text/plain".into(), content: t.to_string() });
        } else {
            out.assets.push(ParsedAsset { kind: kind.into(), key: t.to_string(), attrs: BTreeMap::new() });
        }
    }
    out
}
