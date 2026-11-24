// json.rs - generic JSON / JSONL parsing (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    // Try whole-document JSON array first.
    if let Ok(v) = serde_json::from_str::<serde_json::Value>(raw) {
        walk(&v, &mut out);
        return out;
    }
    // Fall back to JSONL (one object per line).
    for line in raw.lines() {
        let t = line.trim();
        if t.is_empty() { continue; }
        match serde_json::from_str::<serde_json::Value>(t) {
            Ok(v) => walk(&v, &mut out),
            Err(_) => { out.unparsed_count += 1; }
        }
    }
    out
}

fn walk(v: &serde_json::Value, out: &mut ParseOutcome) {
    match v {
        serde_json::Value::Array(a) => for item in a { walk(item, out); },
        serde_json::Value::Object(m) => {
            let title = m.get("title").or(m.get("name")).or(m.get("template-id"))
                .and_then(|x| x.as_str()).unwrap_or("json-object").to_string();
            let key = m.get("host").or(m.get("url")).or(m.get("ip")).or(m.get("value"))
                .and_then(|x| x.as_str()).map(|s| s.to_string());
            if let Some(k) = key {
                out.assets.push(ParsedAsset { kind: "extracted".into(), key: k, attrs: BTreeMap::new() });
            }
            let severity = m.get("severity").and_then(|x| x.as_str()).unwrap_or("info").to_string();
            let detail = serde_json::to_string(v).unwrap_or_default();
            out.findings.push(ParsedFinding { title: title.clone(), detail, severity: super::severity(&severity), discriminator: title });
        }
        _ => {}
    }
}
