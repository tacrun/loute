// parsers/mod.rs — Specialized output parsers (1-5-5.md §6.1, §6.7).
// Each parser: fn(&str) -> ParseOutcome. Parsers return typed values only;
// finding_normalizer owns persistence (§6.2).

pub mod lines;
pub mod json;
pub mod xml;
pub mod nmap;
pub mod masscan;
pub mod nuclei;
pub mod ffuf;
pub mod smb;
pub mod ldap;
pub mod kerberos;
pub mod hashcat;
pub mod airodump;
pub mod tshark;
pub mod generic_table;

// Use the canonical shared types from core::output_parser so every parser produces
// values the finding_normalizer consumes directly (§6.2: parsers never persist).
pub use crate::core::output_parser::{ParseOutcome, ParsedAsset, ParsedArtifact, ParsedFinding};

use crate::core::capability_model::Severity;
pub use std::collections::BTreeMap;

/// Map a severity string to the canonical Severity enum.
pub(crate) fn severity(s: &str) -> Severity {
    match s.to_lowercase().as_str() {
        "critical" => Severity::Critical,
        "high" => Severity::High,
        "medium" | "med" => Severity::Medium,
        "low" => Severity::Low,
        _ => Severity::Info,
    }
}

/// Dispatch a parser id to its implementation.
pub fn parse(parser: &str, raw: &str) -> ParseOutcome {
    match parser {
        "lines" | "text" => lines::parse(raw),
        "json" | "jsonl" => json::parse(raw),
        "xml" => xml::parse(raw),
        "nmap" => nmap::parse(raw),
        "masscan" => masscan::parse(raw),
        "nuclei" => nuclei::parse(raw),
        "ffuf" => ffuf::parse(raw),
        "smb" => smb::parse(raw),
        "ldap" => ldap::parse(raw),
        "kerberos" => kerberos::parse(raw),
        "hashcat" => hashcat::parse(raw),
        "airodump" => airodump::parse(raw),
        "tshark" => tshark::parse(raw),
        "generic_table" => generic_table::parse(raw),
        _ => lines::parse(raw),
    }
}

pub(crate) fn looks_like_domain(s: &str) -> bool {
    if !s.contains('.') { return false; }
    if s.contains(' ') || s.contains('/') { return false; }
    s.split('.').all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_alphanumeric() || c == '-'))
}

pub(crate) fn looks_like_ip(s: &str) -> bool {
    let parts: Vec<_> = s.split('.').collect();
    parts.len() == 4 && parts.iter().all(|p| p.parse::<u8>().is_ok())
}

pub(crate) fn looks_like_url(s: &str) -> bool {
    s.starts_with("http://") || s.starts_with("https://")
}
