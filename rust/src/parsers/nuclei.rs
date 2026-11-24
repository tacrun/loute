// nuclei.rs — nuclei JSONL findings (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    for line in raw.lines() {
        let t = line.trim();
        if t.is_empty() { continue; }
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(t) {
            let tid = v.get("template-id").and_then(|x| x.as_str()).unwrap_or("nuclei").to_string();
            let severity = v.get("info").and_then(|i| i.get("severity")).and_then(|x| x.as_str())
                .or_else(|| v.get("severity").and_then(|x| x.as_str())).unwrap_or("info").to_string();
            let host = v.get("host").or(v.get("url")).and_then(|x| x.as_str()).unwrap_or("").to_string();
            let matched = v.get("matched-at").and_then(|x| x.as_str()).unwrap_or(&host).to_string();
            if !host.is_empty() {
                out.assets.push(ParsedAsset { kind: "url".into(), key: host.clone(), attrs: BTreeMap::new() });
            }
            out.findings.push(ParsedFinding {
                title: tid.clone(), detail: matched, severity: super::severity(&severity), discriminator: tid,
            });
        } else {
            out.unparsed_count += 1;
        }
    }
    out
}

#[cfg(test)] mod tests {
    use super::*;
    #[test] fn parses_nuclei_jsonl() {
        let line = r#"{"template-id":"CVE-2021-44228","info":{"severity":"critical"},"host":"https://x.io","matched-at":"https://x.io/a"}"#;
        let o = parse(line);
        assert_eq!(o.findings.len(), 1);
        assert_eq!(o.findings[0].severity.label(), "critical");
    }
}
