// masscan.rs — masscan output (§6.7). "Discovered open port 80/tcp on 1.2.3.4"
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    for line in raw.lines() {
        let t = line.trim();
        if t.starts_with("Discovered open port") {
            let parts: Vec<&str> = t.split_whitespace().collect();
            // Discovered open port 80/tcp on 1.2.3.4
            if let (Some(pp), Some(ip)) = (parts.get(3), parts.last()) {
                let mut attrs = BTreeMap::new();
                attrs.insert("host".into(), (*ip).to_string());
                out.assets.push(ParsedAsset { kind: "port".into(), key: (*pp).to_string(), attrs });
            }
        } else if let Some((host, port)) = parse_bannercsv(t) {
            let mut attrs = BTreeMap::new();
            attrs.insert("host".into(), host);
            out.assets.push(ParsedAsset { kind: "port".into(), key: port, attrs });
        }
    }
    out
}

fn parse_bannercsv(t: &str) -> Option<(String, String)> {
    let f: Vec<&str> = t.split(',').collect();
    if f.len() >= 4 && f[0].trim().parse::<u8>().is_ok() {
        Some((f[3].trim().to_string(), format!("{}/{}", f[0].trim(), f[1].trim())))
    } else { None }
}

#[cfg(test)] mod tests {
    use super::*;
    #[test] fn parses_discovered_line() {
        let o = parse("Discovered open port 443/tcp on 1.2.3.4\n");
        assert!(o.assets.iter().any(|a| a.kind == "port" && a.key == "443/tcp"));
    }
}
