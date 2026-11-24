// generic_table.rs — whitespace/CSV table heuristic parser (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    for line in raw.lines() {
        let t = line.trim();
        if t.is_empty() || t.starts_with('#') { continue; }
        let cells: Vec<&str> = if t.contains(',') {
            t.split(',').map(|x| x.trim()).collect()
        } else {
            t.split_whitespace().collect()
        };
        if cells.len() < 2 { out.unparsed_count += 1; continue; }
        let key = cells[0].to_string();
        let kind = if looks_like_ip(&key) { "ip" }
            else if looks_like_domain(&key) { "domain" }
            else if looks_like_url(&key) { "url" }
            else { "extracted" };
        let mut attrs = BTreeMap::new();
        for (i, c) in cells.iter().enumerate().skip(1).take(8) {
            attrs.insert(format!("col{}", i), (*c).to_string());
        }
        out.assets.push(ParsedAsset { kind: kind.into(), key, attrs });
    }
    out
}
