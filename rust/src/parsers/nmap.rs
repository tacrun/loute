// nmap.rs — nmap normal/port output and XML (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    // XML form: delegate tag extraction, then parse ports.
    if raw.trim_start().starts_with("<?xml") || raw.contains("<nmaprun") {
        let x = xml::parse(raw);
        out.assets.extend(x.assets);
    }
    // Normal output: "80/tcp  open  http  Apache 2.4"
    for line in raw.lines() {
        let t = line.trim();
        if let Some(port) = parse_port_line(t) {
            let mut attrs = BTreeMap::new();
            attrs.insert("state".into(), port.state.clone());
            attrs.insert("service".into(), port.service.clone());
            out.assets.push(ParsedAsset { kind: "port".into(), key: format!("{}/{}", port.port, port.proto), attrs });
            if !port.version.is_empty() {
                out.assets.push(ParsedAsset { kind: "service".into(), key: port.version.clone(), attrs: BTreeMap::new() });
            }
        }
    }
    if out.assets.is_empty() { out.unparsed_count += 1; }
    out
}

struct Port { port: String, proto: String, state: String, service: String, version: String }

fn parse_port_line(t: &str) -> Option<Port> {
    let parts: Vec<&str> = t.split_whitespace().collect();
    if parts.len() < 3 { return None; }
    let mut pp = parts[0].split('/');
    let port = pp.next()?.to_string();
    if port.parse::<u16>().is_err() { return None; }
    let proto = pp.next().unwrap_or("tcp").to_string();
    let state = parts[1].to_string();
    if state != "open" && state != "filtered" && state != "closed" { return None; }
    let service = parts.get(2).copied().unwrap_or("").to_string();
    let version = parts.get(3..).map(|s| s.join(" ")).unwrap_or_default();
    Some(Port { port, proto, state, service, version })
}

#[cfg(test)] mod tests {
    use super::*;
    #[test] fn parses_port_line() {
        let o = parse("80/tcp   open  http    Apache httpd 2.4.57\n");
        assert!(o.assets.iter().any(|a| a.kind == "port" && a.key == "80/tcp"));
    }
}
