// output_parser.rs - Parser dispatch per 1-5-5.md §6.7.
// ParserId → fn(&str) -> ParseOutcome.
// lines → one Asset/Finding candidate per line.
// json → serde into the capability's json_schema.

use super::capability_model::*;

#[derive(Debug, Clone, Default)]
pub struct ParseOutcome {
    pub assets: Vec<ParsedAsset>,
    pub findings: Vec<ParsedFinding>,
    pub artifacts: Vec<ParsedArtifact>,
    pub unparsed_count: u32,
}

#[derive(Debug, Clone)]
pub struct ParsedAsset {
    pub kind: String,
    pub key: String,
    pub attrs: std::collections::BTreeMap<String, String>,
}

#[derive(Debug, Clone)]
pub struct ParsedFinding {
    pub title: String,
    pub detail: String,
    pub severity: Severity,
    pub discriminator: String,
}

#[derive(Debug, Clone)]
pub struct ParsedArtifact {
    pub media_type: String,
    pub content: String,
}

/// Parse output based on parser ID and output mode.
pub fn parse(parser: &str, _output: OutputMode, raw: &str) -> ParseOutcome {
    match parser {
        "lines" => parse_lines(raw),
        "json" => parse_json(raw),
        "nmap" => parse_nmap(raw),
        "nuclei" => parse_nuclei(raw),
        "ffuf" => parse_ffuf(raw),
        "generic_table" => parse_generic_table(raw),
        _ => parse_lines(raw),
    }
}

fn parse_lines(raw: &str) -> ParseOutcome {
    let mut outcome = ParseOutcome::default();
    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        // Each non-empty line is a potential asset (subdomain/IP/URL)
        if looks_like_domain(trimmed) {
            outcome.assets.push(ParsedAsset {
                kind: "subdomain".into(),
                key: trimmed.to_string(),
                attrs: Default::default(),
            });
        } else if looks_like_ip(trimmed) {
            outcome.assets.push(ParsedAsset {
                kind: "ip".into(),
                key: trimmed.to_string(),
                attrs: Default::default(),
            });
        } else if trimmed.starts_with("http") {
            outcome.assets.push(ParsedAsset {
                kind: "url".into(),
                key: trimmed.to_string(),
                attrs: Default::default(),
            });
        } else {
            outcome.unparsed_count += 1;
            outcome.artifacts.push(ParsedArtifact {
                media_type: "text/plain".into(),
                content: trimmed.to_string(),
            });
        }
    }
    outcome
}

fn parse_json(raw: &str) -> ParseOutcome {
    let mut outcome = ParseOutcome::default();
    match serde_json::from_str::<serde_json::Value>(raw) {
        Ok(val) => {
            if let Some(arr) = val.as_array() {
                for item in arr {
                    if let Some(obj) = item.as_object() {
                        let key = obj
                            .get("name")
                            .or(obj.get("host"))
                            .or(obj.get("url"))
                            .and_then(|v| v.as_str())
                            .unwrap_or("");
                        if !key.is_empty() {
                            outcome.assets.push(ParsedAsset {
                                kind: "subdomain".into(),
                                key: key.to_string(),
                                attrs: Default::default(),
                            });
                        }
                    }
                }
            } else if let Some(obj) = val.as_object() {
                for (k, v) in obj {
                    outcome.assets.push(ParsedAsset {
                        kind: "generic".into(),
                        key: k.clone(),
                        attrs: std::iter::once((
                            "value".into(),
                            v.to_string(),
                        ))
                        .collect(),
                    });
                }
            }
        }
        Err(_) => {
            outcome.unparsed_count += 1;
        }
    }
    outcome
}

fn parse_nmap(raw: &str) -> ParseOutcome {
    let mut outcome = ParseOutcome::default();
    for line in raw.lines() {
        if line.contains("open") {
            // Extract port and service
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 3 {
                let port_service = parts[0]; // e.g. "80/tcp"
                let state = parts[1]; // "open"
                let service = parts[2]; // "http"
                if state == "open" {
                    outcome.assets.push(ParsedAsset {
                        kind: "port".into(),
                        key: port_service.to_string(),
                        attrs: std::iter::once((
                            "service".into(),
                            service.to_string(),
                        ))
                        .collect(),
                    });
                }
            }
        }
    }
    outcome
}

fn parse_nuclei(raw: &str) -> ParseOutcome {
    let mut outcome = ParseOutcome::default();
    for line in raw.lines() {
        if let Ok(val) = serde_json::from_str::<serde_json::Value>(line) {
            let template_id = val.get("template-id").and_then(|v| v.as_str());
            if let Some(tid) = template_id {
                let severity_str = val
                    .get("info")
                    .and_then(|v| v.get("severity"))
                    .and_then(|v| v.as_str())
                    .unwrap_or("info");
                let severity = match severity_str.to_lowercase().as_str() {
                    "critical" => Severity::Critical,
                    "high" => Severity::High,
                    "medium" => Severity::Medium,
                    "low" => Severity::Low,
                    _ => Severity::Info,
                };
                let matched = val
                    .get("matched-at")
                    .and_then(|v| v.as_str())
                    .unwrap_or("");
                outcome.findings.push(ParsedFinding {
                    title: tid.to_string(),
                    detail: matched.to_string(),
                    severity,
                    discriminator: tid.to_string(),
                });
            }
        }
    }
    outcome
}

fn parse_ffuf(raw: &str) -> ParseOutcome {
    let mut outcome = ParseOutcome::default();
    if let Ok(val) = serde_json::from_str::<serde_json::Value>(raw) {
        if let Some(results) = val.get("results").and_then(|v| v.as_array()) {
            for item in results {
                let url = item
                    .get("url")
                    .and_then(|v| v.as_str())
                    .unwrap_or("");
                let status = item
                    .get("status")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0);
                if !url.is_empty() {
                    outcome.assets.push(ParsedAsset {
                        kind: "url".into(),
                        key: url.to_string(),
                        attrs: std::iter::once((
                            "status".into(),
                            status.to_string(),
                        ))
                        .collect(),
                    });
                }
            }
        }
    }
    outcome
}

fn parse_generic_table(raw: &str) -> ParseOutcome {
    let mut outcome = ParseOutcome::default();
    for line in raw.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }
        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.len() >= 2 {
            outcome.assets.push(ParsedAsset {
                kind: "generic".into(),
                key: parts[0].to_string(),
                attrs: std::iter::once((
                    "value".into(),
                    parts[1..].join(" "),
                ))
                .collect(),
            });
        } else {
            outcome.unparsed_count += 1;
        }
    }
    outcome
}

fn looks_like_domain(s: &str) -> bool {
    if !s.contains('.') {
        return false;
    }
    s.chars().all(|c| c.is_alphanumeric() || c == '.' || c == '-' || c == '_')
}

fn looks_like_ip(s: &str) -> bool {
    let parts: Vec<&str> = s.split('.').collect();
    parts.len() == 4 && parts.iter().all(|p| p.parse::<u8>().is_ok())
}
