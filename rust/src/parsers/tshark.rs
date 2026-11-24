// tshark.rs — tshark PDML/field output (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    // tshark -T fields: tab-separated protocol fields; extract IPs and hostnames.
    for line in raw.lines() {
        for tok in line.split(|c: char| c == '\t' || c == ',') {
            let t = tok.trim();
            if looks_like_ip(t) {
                out.assets.push(ParsedAsset { kind: "ip".into(), key: t.to_string(), attrs: BTreeMap::new() });
            } else if looks_like_domain(t) {
                out.assets.push(ParsedAsset { kind: "domain".into(), key: t.to_string(), attrs: BTreeMap::new() });
            }
        }
    }
    if out.assets.is_empty() && !raw.trim().is_empty() {
        out.artifacts.push(ParsedArtifact { media_type: "application/vnd.tcpdump.pcap".into(), content: raw.chars().take(64).collect() });
    }
    out
}
