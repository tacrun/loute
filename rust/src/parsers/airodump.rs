// airodump.rs — airodump-ng CSV (§6.7). AP and client sections.
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    let mut in_client = false;
    for line in raw.lines() {
        let t = line.trim();
        if t.starts_with("Station MAC") { in_client = true; continue; }
        if t.starts_with("BSSID") || t.starts_with("CH ") { continue; }
        let f: Vec<&str> = t.split(',').map(|x| x.trim()).collect();
        if f.len() < 4 { continue; }
        if !looks_like_mac(f[0]) { continue; }
        if in_client {
            out.assets.push(ParsedAsset { kind: "client".into(), key: f[0].to_string(), attrs: BTreeMap::new() });
        } else {
            let mut attrs = BTreeMap::new();
            if f.len() > 13 { attrs.insert("essid".into(), f[13].to_string()); }
            if f.len() > 3 { attrs.insert("channel".into(), f[3].to_string()); }
            out.assets.push(ParsedAsset { kind: "ap".into(), key: f[0].to_string(), attrs });
        }
    }
    out
}

fn looks_like_mac(s: &str) -> bool {
    s.chars().filter(|c| *c == ':').count() == 5 && s.len() >= 17
}

#[cfg(test)] mod tests {
    use super::*;
    #[test] fn parses_ap() {
        let o = parse("BSSID, First seen, Last seen, CH, MB, ...\nAA:BB:CC:DD:EE:FF, 2024-01-01, 2024-01-01, 6, 54, ...\n");
        assert!(o.assets.iter().any(|a| a.kind == "ap" && a.key == "AA:BB:CC:DD:EE:FF"));
    }
}
