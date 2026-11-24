// smb.rs - SMB share/session enumeration output (§6.7).
use super::*;

pub fn parse(raw: &str) -> ParseOutcome {
    let mut out = ParseOutcome::default();
    for line in raw.lines() {
        let t = line.trim();
        // netexec/smbclient share lines: "  IPC$          IPC       remote IPC"
        if t.contains('$') || (t.split_whitespace().count() >= 2 && t.starts_with(char::is_whitespace)) {
            let name = t.split_whitespace().next().unwrap_or("");
            if !name.is_empty() {
                out.assets.push(ParsedAsset { kind: "share".into(), key: name.to_string(), attrs: BTreeMap::new() });
                continue;
            }
        }
        if t.to_lowercase().contains("authentication") || t.contains("(Pwn3d!)") {
            out.findings.push(ParsedFinding { title: "SMB AUTHENTICATION".into(), detail: t.to_string(), severity: super::severity("high"), discriminator: t.to_string() });
        }
    }
    out
}
