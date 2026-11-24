// ffuf.rs - ffuf JSON output (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(raw) {
        if let Some(results) = v.get("results").and_then(|x| x.as_array()) {
            for r in results {
                let url = r.get("url").and_then(|x| x.as_str()).unwrap_or("").to_string();
                let status = r.get("status").and_then(|x| x.as_u64()).unwrap_or(0);
                let length = r.get("length").and_then(|x| x.as_u64()).unwrap_or(0);
                let mut attrs = BTreeMap::new();
                attrs.insert("status".into(), status.to_string());
                attrs.insert("length".into(), length.to_string());
                out.assets.push(ParsedAsset { kind: "endpoint".into(), key: url, attrs });
            }
            return out;
        }
    }
    // CSV-ish lines fallback.
    for line in raw.lines() {
        if line.contains("http") {
            out.unparsed_count += 1;
            out.artifacts.push(ParsedArtifact { media_type: "text/plain".into(), content: line.to_string() });
        }
    }
    out
}
