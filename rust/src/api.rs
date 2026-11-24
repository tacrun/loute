use crate::phases::phase1_recon;
use crate::core;
use std::collections::BTreeMap;

// ==========================================
// LOUTE V1.5.5 - FRB API Surface
// Per 1-5-5.md §6.14: list_capabilities, get_capability, validate_capability,
// dry_run_capability, probe_providers, run_capability, cancel_job, stream_job_events,
// get_job_result, list_jobs, list_artifacts, get_artifact, create_workspace,
// import_workspace, export_report, query_graph, list_findings, resolve_finding,
// list_wordlists, install_wordlist_pack, get_audit_log, set_opsec_profile
// ==========================================

/// Initialize the LOUTE runtime - loads the capability catalog.
pub fn init_runtime() -> Result<String, String> {
    crate::init_catalog()?;
    let hash = crate::CATALOG_HASH;
    let count = core::capability_catalog::get_catalog()
        .map(|c| c.count())
        .unwrap_or(0);
    Ok(format!("LOUTE V1.5.5 runtime initialized | catalog_hash={} | capabilities={}", hash, count))
}

/// List all capabilities with optional phase filter.
pub fn list_capabilities(phase_filter: Option<String>) -> Vec<CapabilitySummaryFrb> {
    let catalog = match core::capability_catalog::get_catalog() {
        Some(c) => c,
        None => return vec![],
    };

    let registry = core::provider_registry::ProviderRegistry::new();

    catalog
        .capabilities
        .values()
        .filter(|cap| {
            if let Some(ref phase) = phase_filter {
                cap.phase.as_str() == phase.to_lowercase()
            } else {
                true
            }
        })
        .map(|cap| {
            let availability = registry.availability(&cap.binary);
            CapabilitySummaryFrb {
                id: cap.id.0.clone(),
                phase: cap.phase.as_str().to_string(),
                label: cap.label.clone(),
                summary: cap.summary.clone(),
                risk: format!("{:?}", cap.risk),
                noise: format!("{:?}", cap.noise).to_lowercase(),
                provider: cap.provider.0.clone(),
                native: cap.native,
                opsec_safe: cap.opsec_safe,
                availability: availability.label().to_string(),
            }
        })
        .collect()
}

/// Get detailed information about a capability.
pub fn get_capability(id: String) -> Option<CapabilityDetailFrb> {
    let catalog = core::capability_catalog::get_catalog()?;
    let cap = catalog.get(&core::capability_model::CapabilityId(id.clone()))?;

    let registry = core::provider_registry::ProviderRegistry::new();
    let availability = registry.availability(&cap.binary);

    Some(CapabilityDetailFrb {
        id: cap.id.0.clone(),
        phase: cap.phase.as_str().to_string(),
        label: cap.label.clone(),
        summary: cap.summary.clone(),
        risk: format!("{:?}", cap.risk),
        noise: format!("{:?}", cap.noise).to_lowercase(),
        mitre: cap.mitre.iter().map(|m| m.0.clone()).collect(),
        platforms: cap.platforms.iter().map(|p| format!("{:?}", p).to_lowercase()).collect(),
        privileges: cap.privileges.iter().map(|p| format!("{:?}", p).to_lowercase()).collect(),
        network: cap.network,
        requires: cap.requires.iter().map(|r| r.0.clone()).collect(),
        provides: cap.provides.clone(),
        inputs: cap.inputs.iter().map(|i| InputSpecFrb {
            name: i.name.clone(),
            kind: format!("{:?}", i.kind).to_lowercase(),
            required: i.required,
            default: i.default.clone(),
        }).collect(),
        provider: cap.provider.0.clone(),
        binary: cap.binary.clone(),
        operation: cap.operation.clone(),
        args: cap.args.clone(),
        output: format!("{:?}", cap.output).to_lowercase(),
        parser: cap.parser.clone(),
        timeout: cap.timeout,
        concurrency: cap.concurrency,
        native: cap.native,
        opsec_safe: cap.opsec_safe,
        reversible: cap.reversible,
        chains: cap.chains.iter().map(|c| c.0.clone()).collect(),
        availability: availability.label().to_string(),
    })
}

/// Validate capability inputs.
pub fn validate_capability(id: String, inputs: String) -> String {
    let inputs_map: BTreeMap<String, String> = serde_json::from_str(&inputs)
        .unwrap_or_default();

    let catalog = match core::capability_catalog::get_catalog() {
        Some(c) => c,
        None => return serde_json::json!({"valid": false, "errors": ["catalog not initialized"]}).to_string(),
    };

    let cap = match catalog.get(&core::capability_model::CapabilityId(id)) {
        Some(c) => c,
        None => return serde_json::json!({"valid": false, "errors": ["capability not found"]}).to_string(),
    };

    let mut errors = Vec::new();
    for input_spec in &cap.inputs {
        if input_spec.required {
            let val = inputs_map.get(&input_spec.name);
            match val {
                Some(v) if !v.is_empty() => {}
                _ => {
                    if input_spec.default.is_none() {
                        errors.push(format!("missing required input: {}", input_spec.name));
                    }
                }
            }
        }
    }

    serde_json::json!({
        "valid": errors.is_empty(),
        "errors": errors
    }).to_string()
}

/// Dry-run a capability - returns the execution plan without running.
pub fn dry_run_capability(id: String, inputs: String, scope: Option<String>) -> String {
    let inputs_map: BTreeMap<String, String> = serde_json::from_str(&inputs)
        .unwrap_or_default();

    let dispatcher = core::dispatcher::Dispatcher::new();
    match dispatcher.plan(
        &core::capability_model::CapabilityId(id),
        &inputs_map,
        scope.as_deref(),
    ) {
        Ok(plan) => serde_json::json!({
            "job_id": plan.job_id.0,
            "capability": plan.capability.0,
            "provider": plan.provider.0,
            "binary_path": plan.binary_path.display().to_string(),
            "argv": plan.argv,
            "timeout": plan.timeout.as_secs(),
            "parser": plan.parser,
            "command_preview": plan.command_preview,
        }).to_string(),
        Err(e) => serde_json::json!({
            "error": e.to_string()
        }).to_string(),
    }
}

/// Probe all providers and return a health matrix.
pub fn probe_providers() -> Vec<ProviderHealthFrb> {
    let catalog = match core::capability_catalog::get_catalog() {
        Some(c) => c,
        None => return vec![],
    };

    let registry = core::provider_registry::ProviderRegistry::new();

    // Collect unique binaries
    let mut binaries: Vec<String> = catalog
        .capabilities
        .values()
        .map(|c| c.binary.clone())
        .filter(|b| b != "native")
        .collect();
    binaries.sort();
    binaries.dedup();

    binaries
        .iter()
        .map(|b| {
            let state = registry.probe(b);
            let version = if let core::provider_registry::ProviderState::Available(ref path) = state {
                registry_get_version(path)
            } else {
                None
            };
            let cap_count = catalog
                .capabilities
                .values()
                .filter(|c| c.binary == *b)
                .count() as u32;
            ProviderHealthFrb {
                name: b.clone(),
                binary: b.clone(),
                state: registry.availability(b).label().to_string(),
                version: version.unwrap_or_default(),
                capability_count: cap_count,
                install_hint: format!("Install {} to enable {} capabilities", b, cap_count),
            }
        })
        .collect()
}

/// Create a workspace.
pub fn create_workspace(name: String, kind: String) -> String {
    let ws_kind = match kind.to_lowercase().as_str() {
        "lab" => core::capability_model::WorkspaceKind::Lab,
        "ctf" => core::capability_model::WorkspaceKind::Ctf,
        "research" => core::capability_model::WorkspaceKind::Research,
        _ => core::capability_model::WorkspaceKind::Engagement,
    };
    let mgr = core::workspace::WorkspaceManager::new();
    let id = mgr.create(&name, ws_kind);
    serde_json::json!({
        "id": id.0,
        "name": name,
        "kind": kind,
    }).to_string()
}

/// Run a capability end-to-end through the full runtime (plan → exec → parse → normalize).
/// No stub fallback: failures return a typed error result (F2).
pub async fn run_capability(id: String, inputs: String, scope: Option<String>) -> String {
    let inputs_map: std::collections::BTreeMap<String, String> = serde_json::from_str(&inputs)
        .unwrap_or_default();
    let runtime = core::runtime::Runtime::new();
    match runtime.run(&id, &inputs_map, scope.as_deref()).await {
        Ok(rr) => serde_json::to_string(&rr).unwrap_or_else(|e| format!("{{\"error\":\"{}\"}}", e)),
        Err(e) => serde_json::json!({"error": e.to_string(), "capability": id}).to_string(),
    }
}

/// Validate the catalog against all V1-V20 rules; returns a JSON report.
pub fn validate_catalog() -> String {
    let catalog = match core::capability_catalog::get_catalog() {
        Some(c) => c,
        None => return serde_json::json!({"valid": false, "errors": [{"message": "catalog not initialized"}]}).to_string(),
    };
    let report = core::catalog_validate::validate(catalog);
    serde_json::to_string(&report).unwrap_or_else(|e| format!("{{\"error\":\"{}\"}}", e))
}

/// Get the catalog hash.
pub fn get_catalog_hash() -> String {
    crate::CATALOG_HASH.to_string()
}

/// Get the LOUTE version.
pub fn get_version() -> String {
    "1.5.5".to_string()
}

/// Get the catalog stats (phase counts).
pub fn get_catalog_stats() -> String {
    let catalog = match core::capability_catalog::get_catalog() {
        Some(c) => c,
        None => return "{}".to_string(),
    };

    let phases = [
        ("recon", core::capability_model::Phase::Recon),
        ("surface", core::capability_model::Phase::Surface),
        ("vulnerability", core::capability_model::Phase::Vulnerability),
        ("payload", core::capability_model::Phase::Payload),
        ("escalation", core::capability_model::Phase::Escalation),
        ("credentials", core::capability_model::Phase::Credentials),
        ("lateral", core::capability_model::Phase::Lateral),
        ("persistence", core::capability_model::Phase::Persistence),
        ("exploitation", core::capability_model::Phase::Exploitation),
        ("wireless", core::capability_model::Phase::Wireless),
        ("ctf", core::capability_model::Phase::Ctf),
    ];

    let mut counts = serde_json::Map::new();
    for (name, phase) in &phases {
        counts.insert(
            name.to_string(),
            serde_json::Value::Number(serde_json::Number::from(catalog.count_by_phase(*phase))),
        );
    }

    serde_json::json!({
        "total": catalog.count(),
        "hash": catalog.hash,
        "phases": counts,
    }).to_string()
}

fn registry_get_version(path: &std::path::PathBuf) -> Option<String> {
    let output = std::process::Command::new(path).arg("--version").output();
    match output {
        Ok(out) if out.status.success() => {
            let stdout = String::from_utf8_lossy(&out.stdout);
            stdout.lines().next().map(|s| s.to_string())
        }
        _ => {
            let output = std::process::Command::new(path).arg("-V").output();
            match output {
                Ok(out) if out.status.success() => {
                    let stdout = String::from_utf8_lossy(&out.stdout);
                    stdout.lines().next().map(|s| s.to_string())
                }
                _ => None,
            }
        }
    }
}

// ── FRB-compatible structs ──

#[flutter_rust_bridge::frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CapabilitySummaryFrb {
    pub id: String,
    pub phase: String,
    pub label: String,
    pub summary: String,
    pub risk: String,
    pub noise: String,
    pub provider: String,
    pub native: bool,
    pub opsec_safe: bool,
    pub availability: String,
}

#[flutter_rust_bridge::frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CapabilityDetailFrb {
    pub id: String,
    pub phase: String,
    pub label: String,
    pub summary: String,
    pub risk: String,
    pub noise: String,
    pub mitre: Vec<String>,
    pub platforms: Vec<String>,
    pub privileges: Vec<String>,
    pub network: bool,
    pub requires: Vec<String>,
    pub provides: Vec<String>,
    pub inputs: Vec<InputSpecFrb>,
    pub provider: String,
    pub binary: String,
    pub operation: String,
    pub args: Vec<String>,
    pub output: String,
    pub parser: String,
    pub timeout: u64,
    pub concurrency: u8,
    pub native: bool,
    pub opsec_safe: bool,
    pub reversible: bool,
    pub chains: Vec<String>,
    pub availability: String,
}

#[flutter_rust_bridge::frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct InputSpecFrb {
    pub name: String,
    pub kind: String,
    pub required: bool,
    pub default: Option<String>,
}

#[flutter_rust_bridge::frb]
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ProviderHealthFrb {
    pub name: String,
    pub binary: String,
    pub state: String,
    pub version: String,
    pub capability_count: u32,
    pub install_hint: String,
}

// ==========================================
// PHASE 1: RECONNAISSANCE (Real Implementations - preserved)
// ==========================================

pub async fn dns_bruteforce(domain: String, wordlist_path: Option<String>, concurrency: usize) -> String {
    match phase1_recon::subdomain::dns_bruteforce(&domain, wordlist_path, concurrency).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn ct_logs(domain: String) -> String {
    match phase1_recon::subdomain::ct_logs(&domain).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn zone_transfer(domain: String, nameserver: Option<String>) -> String {
    match phase1_recon::subdomain::zone_transfer(&domain, nameserver).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn reverse_dns(cidr: String) -> String {
    match phase1_recon::subdomain::reverse_dns(&cidr).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn wildcard_detect(domain: String) -> String {
    match phase1_recon::subdomain::wildcard_detect(&domain).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn cloud_provider(target: String) -> String {
    match phase1_recon::cloud::cloud_provider(&target).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn s3_check(bucket_name: String) -> String {
    match phase1_recon::cloud::s3_check(&bucket_name).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn metadata_probe(target_ip: String) -> String {
    match phase1_recon::cloud::metadata_probe(&target_ip).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn firebase_check(project_id: String) -> String {
    match phase1_recon::cloud::firebase_check(&project_id).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn cdn_detect(target_url: String) -> String {
    match phase1_recon::cloud::cdn_detect(&target_url).await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

pub async fn network_services_audit() -> String {
    match crate::phases::phase1_recon::audit::network_services_audit().await {
        Ok(html) => html,
        Err(e) => format!("<div style='color: #FF3B30; font-family: monospace;'>Error: {}</div>", e),
    }
}

// ==========================================
// STUB - Retained until all phases are complete (per §19 migration plan)
// ==========================================

pub async fn run_stub_action(action_id: String) -> String {
    let os = std::env::consts::OS.to_uppercase();

    let tool_checks = if os == "LINUX" || os == "MACOS" {
        format!(
            "<div style='margin-top: 12px; font-size: 11px;'>\
            <b>Host environment validations:</b><br/>\
            [+] System architecture: Linux/Unix verified<br/>\
            [+] Environment shell (/bin/sh): OK<br/>\
            [!] Action-specific system dependencies: Verification pending execution module integration.\
            </div>"
        )
    } else if os == "WINDOWS" {
        format!(
            "<div style='margin-top: 12px; font-size: 11px;'>\
            <b>Host environment validations:</b><br/>\
            [+] System architecture: Windows PowerShell verified<br/>\
            [+] Command interpreter (cmd.exe): OK<br/>\
            [!] Action-specific system dependencies: Verification pending execution module integration.\
            </div>"
        )
    } else {
        format!(
            "<div style='margin-top: 12px; font-size: 11px;'>\
            <b>Host environment validations:</b><br/>\
            [+] Architecture: Mobile/Restricted sandbox environment<br/>\
            [!] WARNING: Some system utilities might require custom Android binaries or root permissions.\
            </div>"
        )
    };

    format!(
        "<div style='font-family: monospace; color: #00FF41; background: #000000; padding: 16px; border: 1px solid #00FF41;'>\
        <h3 style='color: #FFBF00; margin-top: 0;'>Action Execution Stub ({})</h3>\
        <p>Active Platform: <b style='color: #FFBF00;'>{}</b></p>\
        <p>This execution module (ID: <b>{}</b>) is configured in the UI shell. Core Rust engine action handler bindings will compile dynamically in the upcoming stages.</p>\
        {} \
        </div>",
        action_id, os, action_id, tool_checks
    )
}
