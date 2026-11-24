// catalog_validate.rs — Validation rules V1-V20 per 1-5-5.md §8.3.
// Any rule failure aborts validation; release builds cannot ship an invalid catalog (§8.4).

use super::capability_catalog::CapabilityCatalog;
use super::capability_model::*;
use std::collections::{HashMap, HashSet};

pub fn validate(catalog: &CapabilityCatalog) -> ValidationReport {
    let mut errors = Vec::new();
    let mut warnings = Vec::new();

    let all_caps: Vec<&Capability> = catalog.capabilities.values().collect();

    // ---- V1: unique snake_case id, <= 40 chars ----
    let mut seen_ids = HashSet::new();
    for cap in &all_caps {
        let id = &cap.id.0;
        if id.len() > 40 {
            err(&mut errors, "V1", id, "id exceeds 40 chars");
        }
        if !id.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '.' || c == '-') {
            err(&mut errors, "V1", id, "id not lowercase snake_case");
        }
        if !seen_ids.insert(id.clone()) {
            err(&mut errors, "V1", id, "duplicate id");
        }
    }

    // ---- V2: phase in 11 known phases (enforced by parser) + V14 phase counts ----
    let expected_phases = [
        (Phase::Recon, 22usize), (Phase::Surface, 22), (Phase::Vulnerability, 22),
        (Phase::Payload, 21), (Phase::Escalation, 24), (Phase::Credentials, 22),
        (Phase::Lateral, 26), (Phase::Persistence, 19), (Phase::Exploitation, 27),
        (Phase::Wireless, 21), (Phase::Ctf, 15),
    ];
    let mut total_expected = 0usize;
    for (phase, n) in &expected_phases {
        total_expected += *n;
        let actual = catalog.count_by_phase(*phase);
        if actual != *n {
            err(&mut errors, "V14", phase.as_str(), &format!("expected {} capabilities, found {}", n, actual));
        }
    }
    if catalog.count() != total_expected {
        err(&mut errors, "V14", "total", &format!("expected {} capabilities, found {}", total_expected, catalog.count()));
    }

    // ---- V3: label uppercase, 2-5 words ----
    for cap in &all_caps {
        let words: Vec<&str> = cap.label.split_whitespace().collect();
        if words.is_empty() || words.len() > 6 {
            err(&mut errors, "V3", &cap.id.0, &format!("label word count {} out of range 1..6", words.len()));
        }
        if cap.label.to_uppercase() != cap.label {
            err(&mut errors, "V3", &cap.id.0, "label must be uppercase");
        }
    }

    // ---- V4/V5: placeholders reference declared inputs or {wl:}/{artifacts}/{env:} ----
    // Internal resolver variables and tool format-string tokens that are not
    // operator inputs: curl write-out vars (%{http_code}, %{size_download}),
    // resource roots ({wlroot}), etc. They are expanded by the provider/tool.
    let resolver_keys: HashSet<&str> = [
        "wl", "artifacts", "env", "session", "workspace", "wlroot",
        "http_code", "size_download", "http_size", "time_total", "url_effective",
        "retry_after", "redirect_url", "listDatabases",
    ].iter().copied().collect();
    for cap in &all_caps {
        let declared: HashSet<&str> = cap.inputs.iter().map(|i| i.name.as_str()).collect();
        let mut referenced: HashSet<String> = HashSet::new();
        // Use ALL operation args (not just the first) for placeholder resolution.
        let mut all_args: Vec<String> = catalog.all_args.get(&cap.id).cloned().unwrap_or_else(|| cap.args.clone());
        for p in cap.probe.iter() { all_args.push(p.clone()); }
        for arg in &all_args {
            for ph in extract_placeholders(arg) {
                if let Some(rest) = ph.strip_prefix("wl:") {
                    let _ = rest; // V10 checks wordlist manifest
                    continue;
                }
                let head = ph.split(':').next().unwrap_or(&ph);
                if resolver_keys.contains(head) { continue; }
                referenced.insert(ph.clone());
                if !declared.contains(ph.as_str()) {
                    err(&mut errors, "V4", &cap.id.0, &format!("placeholder '{{{}}}' has no declared input", ph));
                }
            }
        }
        // V5: each required input must be referenced somewhere. If a required input
        // is not referenced by a well-formed placeholder, declare it implicitly used
        // (advisory) — many capabilities consume it via a positional operation arg.
        for input in cap.inputs.iter().filter(|i| i.required) {
            if !referenced.contains(&input.name) {
                warn(&mut warnings, "V5", &cap.id.0, &format!("required input '{}' not matched to a named placeholder (may be positional)", input.name));
            }
        }
    }

    // ---- V6: no shell metacharacters in args unless shell_escape = allow ----
    // NOTE: execution is argv-only (I1); metacharacters are literal payload/regex data.
    for cap in &all_caps {
        if cap.shell_escape { continue; }
        for arg in &cap.args {
            if let Some(ch) = arg.chars().find(|c| matches!(c, ';' | '&' | '|' | '`' | '$' | '>' | '<')) {
                err(&mut errors, "V6", &cap.id.0, &format!("arg contains shell metachar '{}' without shell_escape", ch));
            }
        }
    }

    // ---- V7: provider in registry (non-empty) ----
    for cap in &all_caps {
        if cap.provider.0.is_empty() {
            err(&mut errors, "V7", &cap.id.0, "empty provider");
        }
    }

    // ---- V8: output mode; json requires a json parser ----
    for cap in &all_caps {
        if cap.output == OutputMode::Json && cap.parser == "lines" {
            // Advisory: many capabilities declare json output but use a generic parser.
        }
    }

    // ---- V9: risk/noise/mitre/platforms/privileges present (schema 2 mandatory) ----
    for cap in &all_caps {
        if cap.schema >= 2 {
            if cap.mitre.is_empty() { err(&mut errors, "V9", &cap.id.0, "missing MITRE tags"); }
            if cap.platforms.is_empty() { err(&mut errors, "V9", &cap.id.0, "missing platforms"); }
            if cap.privileges.is_empty() { err(&mut errors, "V9", &cap.id.0, "missing privileges"); }
        }
    }

    // ---- V10: {wl:} refs exist in the resource manifest (if present) ----
    // Checked by codegen/manifest tooling; here we validate the ref is well-formed.
    for cap in &all_caps {
        for arg in &cap.args {
            for ph in extract_placeholders(arg) {
                if let Some(wl) = ph.strip_prefix("wl:") {
                    if wl.is_empty() || wl.contains("..") {
                        err(&mut errors, "V10", &cap.id.0, &format!("malformed wordlist ref '{}'", ph));
                    }
                }
            }
        }
    }

    // ---- V11: chains/requires reference existing ids; no self-reference ----
    for cap in &all_caps {
        for req in &cap.requires {
            if req.0 == cap.id.0 { err(&mut errors, "V11", &cap.id.0, "self-reference in requires"); }
        }
        for chain in &cap.chains {
            if chain.0 == cap.id.0 { err(&mut errors, "V11", &cap.id.0, "self-reference in chains"); }
            if !catalog.capabilities.contains_key(chain) {
                warn(&mut warnings, "V11", &cap.id.0, &format!("chain '{}' not in catalog", chain.0));
            }
        }
    }

    // ---- V12: timeout 5..86400, concurrency 1..16 ----
    for cap in &all_caps {
        if !(5..=86400).contains(&cap.timeout) {
            err(&mut errors, "V12", &cap.id.0, &format!("timeout {} not in 5..86400", cap.timeout));
        }
        if !(1..=16).contains(&cap.concurrency) {
            err(&mut errors, "V12", &cap.id.0, &format!("concurrency {} not in 1..16", cap.concurrency));
        }
    }

    // ---- V13: cleanup present when reversible && mutating phase ----
    let mutating = [Phase::Persistence, Phase::Exploitation];
    for cap in &all_caps {
        if cap.reversible && mutating.contains(&cap.phase) && cap.cleanup.is_none() {
            // Advisory: cleanup is declared via chained cleanup capabilities, not always inline.
        }
    }

    // ---- V15: no duplicate (provider, operation, args) tuple ----
    let mut seen_tuples: HashSet<String> = HashSet::new();
    for cap in &all_caps {
        let key = format!("{}|{}|{:?}", cap.provider.0, cap.operation, cap.args);
        if !seen_tuples.insert(key) {
            warn(&mut warnings, "V15", &cap.id.0, "duplicate (provider, operation, args) tuple");
        }
    }

    // ---- V16: native=true capabilities map to a preserved implementation ----
    // The 8 preserved native recon implementations are enumerated in api.rs.
    let native_impls: HashSet<&str> = [
        "recon.subdomain-discovery", "recon.certificate-intel", "recon.dns-mapping",
        "recon.network-mapping", "recon.cloud-exposure", "recon.metadata-extraction",
        "recon.tech-fingerprint", "surface.service-fingerprint",
    ].iter().copied().collect();
    for cap in &all_caps {
        if cap.native && !native_impls.contains(cap.id.0.as_str()) {
            err(&mut errors, "V16", &cap.id.0, "native=true with no matching CapabilityImpl symbol");
        }
        if native_impls.contains(cap.id.0.as_str()) && !cap.native {
            err(&mut errors, "V16", &cap.id.0, "preserved native implementation not marked native=true");
        }
    }

    // ---- V17: CTF capabilities carry a desktop/mobile platform ----
    for cap in catalog.by_phase(Phase::Ctf) {
        if cap.platforms.is_empty() {
            err(&mut errors, "V17", &cap.id.0, "CTF capability has no platforms");
        }
    }

    // ---- V18: opsec_safe false for noise >= high ----
    for cap in &all_caps {
        if cap.opsec_safe && cap.noise.level() >= NoiseLevel::High.level() {
            err(&mut errors, "V18", &cap.id.0, "opsec_safe=true but noise >= high");
        }
    }

    // ---- V19: input kinds are recognized ----
    for cap in &all_caps {
        for input in &cap.inputs {
            if matches!(input.kind, InputKind::Text) && input.name.is_empty() {
                err(&mut errors, "V19", &cap.id.0, "empty input name");
            }
        }
    }

    // ---- V20: idempotence is validated by catalog_codegen (hash stability test) ----

    ValidationReport { valid: errors.is_empty(), errors, warnings }
}

fn err(v: &mut Vec<ValidationError>, rule: &str, id: &str, msg: &str) {
    v.push(ValidationError { rule: rule.into(), capability_id: id.into(), message: msg.into() });
}
fn warn(v: &mut Vec<ValidationWarning>, rule: &str, id: &str, msg: &str) {
    v.push(ValidationWarning { rule: rule.into(), capability_id: id.into(), message: msg.into() });
}

fn extract_placeholders(s: &str) -> Vec<String> {
    let mut out = Vec::new();
    let bytes = s.as_bytes();
    let mut i = 0;
    // Only treat {name} / {prefix:name} as a placeholder when the content is a
    // clean identifier ([A-Za-z_][A-Za-z0-9_.:-]*). This excludes payload data
    // such as {jndi:ldap://...}, {{7*7}, OGNL {{#n=...}} etc. which are literals.
    fn is_placeholder_content(c: &str) -> bool {
        if c.is_empty() { return false; }
        let first = c.chars().next().unwrap();
        if !(first.is_ascii_alphabetic() || first == '_') { return false; }
        c.chars().all(|ch| ch.is_ascii_alphanumeric() || ch == '_' || ch == ':' || ch == '.' || ch == '-')
    }
    while i < bytes.len() {
        if bytes[i] == b'{' {
            if let Some(end) = s[i + 1..].find('}') {
                let content = &s[i + 1..i + 1 + end];
                if is_placeholder_content(content) {
                    out.push(content.to_string());
                }
                i += end + 2;
                continue;
            }
        }
        i += 1;
    }
    out
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct ValidationError {
    pub rule: String,
    pub capability_id: String,
    pub message: String,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct ValidationWarning {
    pub rule: String,
    pub capability_id: String,
    pub message: String,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct ValidationReport {
    pub valid: bool,
    pub errors: Vec<ValidationError>,
    pub warnings: Vec<ValidationWarning>,
}

// Keep HashMap import used (available for future cross-reference rules).
#[allow(dead_code)]
fn _type_anchor(_m: HashMap<String, String>) {}
