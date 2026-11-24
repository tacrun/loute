// dispatcher.rs - CapabilityId → ExecutionPlan per 1-5-5.md §6.3.
// Performs: catalog lookup → input validation → placeholder substitution →
// wordlist resolution → provider resolution → availability check → argv materialization.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Duration;

use super::capability_catalog::get_catalog;
use super::capability_model::*;
use super::provider_registry::ProviderRegistry;

pub struct Dispatcher {
    pub providers: ProviderRegistry,
}

impl Dispatcher {
    pub fn new() -> Self {
        Self {
            providers: ProviderRegistry::new(),
        }
    }

    pub fn plan(
        &self,
        capability_id: &CapabilityId,
        inputs: &BTreeMap<String, String>,
        _scope: Option<&str>,
    ) -> Result<ExecutionPlan, PlanError> {
        let catalog = get_catalog().ok_or(PlanError::Internal("catalog not initialized".into()))?;
        let cap = catalog
            .get(capability_id)
            .ok_or_else(|| PlanError::CapabilityNotFound(capability_id.0.clone()))?;

        // Input validation
        for input_spec in &cap.inputs {
            if input_spec.required {
                let val = inputs.get(&input_spec.name);
                match val {
                    Some(v) if !v.is_empty() => {}
                    _ => {
                        // Check default
                        if input_spec.default.is_none() {
                            return Err(PlanError::InputValidation(format!(
                                "missing required input: {}",
                                input_spec.name
                            )));
                        }
                    }
                }
            }
        }

        // Placeholder substitution
        let resolved_inputs: BTreeMap<String, String> = cap
            .inputs
            .iter()
            .map(|spec| {
                let val = inputs
                    .get(&spec.name)
                    .cloned()
                    .or(spec.default.clone())
                    .unwrap_or_default();
                (spec.name.clone(), val)
            })
            .collect();

        // Provider resolution
        let provider_state = self.providers.probe(&cap.binary);

        // For native capabilities, the binary is the Rust implementation itself
        let binary_path = if cap.native {
            PathBuf::from("(native)")
        } else {
            match provider_state {
                super::provider_registry::ProviderState::Available(ref path) => path.clone(),
                _ => {
                    // Still plan it - execution will handle the missing provider
                    PathBuf::from(&cap.binary)
                }
            }
        };

        // Argv materialization - substitute {placeholder} values
        let argv: Vec<String> = cap
            .args
            .iter()
            .map(|arg| substitute_placeholders(arg, &resolved_inputs))
            .collect();

        // Command preview - byte-identical to argv
        let command_preview = if cap.native {
            format!("(native) {} {:?}", cap.id.0, argv)
        } else {
            format!("{} {}", cap.binary, argv.join(" "))
        };

        let job_id = JobId(format!("job_{}", uuid_like()));

        Ok(ExecutionPlan {
            job_id,
            capability: cap.id.clone(),
            provider: cap.provider.clone(),
            binary_path,
            argv,
            env: BTreeMap::new(),
            cwd: PathBuf::from("."),
            timeout: cap.timeout_duration(),
            retries: cap.retry,
            parser: cap.parser.clone(),
            opsec: "balanced".into(),
            artifact_targets: cap.artifacts.clone(),
            command_preview,
        })
    }
}

/// Description of one provider operation within a capability.
#[derive(Debug, Clone, serde::Serialize)]
pub struct OperationMeta {
    pub index: usize,
    pub name: String,
    pub binary: String,
    pub output: String,
    pub stage: i64,
    pub probe: bool,
}

/// Return every operation of a capability in catalog order (all providers).
pub fn operations_for(id: &str) -> Vec<OperationMeta> {
    let raw = crate::EMBEDDED_CATALOG;
    let value: toml::Value = match toml::from_str(raw) {
        Ok(v) => v,
        Err(_) => return vec![],
    };
    let caps = match value.get("capability").and_then(|v| v.as_array()) {
        Some(c) => c,
        None => return vec![],
    };
    let cap = match caps.iter().find(|c| {
        c.get("id").and_then(|v| v.as_str()) == Some(id)
    }) {
        Some(c) => c,
        None => return vec![],
    };

    let mut out = Vec::new();
    let mut index = 0usize;
    if let Some(providers) = cap.get("provider").and_then(|p| p.as_array()) {
        for p in providers {
            let binary = p.get("binary").and_then(|v| v.as_str()).unwrap_or("native").to_string();
            if let Some(ops) = p.get("operation").and_then(|o| o.as_array()) {
                for op in ops {
                    out.push(OperationMeta {
                        index,
                        name: op.get("name").and_then(|v| v.as_str()).unwrap_or("Run").to_string(),
                        binary: binary.clone(),
                        output: op.get("output").and_then(|v| v.as_str()).unwrap_or("lines").to_string(),
                        stage: op.get("stage").and_then(|v| v.as_integer()).unwrap_or(1),
                        probe: op.get("probe").and_then(|v| v.as_bool()).unwrap_or(false),
                    });
                    index += 1;
                }
            }
        }
    }
    out
}

/// Plan a single operation of a capability by index. This lets the UI present
/// each sub-action (command template) as an independently executable step while
/// keeping argv-only execution and the rest of the runtime contract intact.
pub fn plan_operation(
    id: &str,
    operation_index: usize,
    inputs: &BTreeMap<String, String>,
    scope: Option<&str>,
) -> Result<ExecutionPlan, PlanError> {
    let raw = crate::EMBEDDED_CATALOG;
    let value: toml::Value = toml::from_str(raw)
        .map_err(|e| PlanError::Internal(format!("catalog parse: {e}")))?;
    let caps = value.get("capability").and_then(|v| v.as_array())
        .ok_or_else(|| PlanError::Internal("catalog has no capability array".into()))?;
    let cap = caps.iter().find(|c| c.get("id").and_then(|v| v.as_str()) == Some(id))
        .ok_or_else(|| PlanError::CapabilityNotFound(id.to_string()))?;

    // Flatten operations in the same order as operations_for().
    let mut chosen: Option<(String, Vec<String>, String, u64)> = None;
    let mut index = 0usize;
    'outer: for p in cap.get("provider").and_then(|p| p.as_array()).into_iter().flatten() {
        let binary = p.get("binary").and_then(|v| v.as_str()).unwrap_or("native").to_string();
        for op in p.get("operation").and_then(|o| o.as_array()).into_iter().flatten() {
            if index == operation_index {
                let args = op.get("args").and_then(|v| v.as_array())
                    .map(|a| a.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect())
                    .unwrap_or_default();
                let output = op.get("output").and_then(|v| v.as_str()).unwrap_or("lines").to_string();
                let timeout = op.get("timeout").and_then(|v| v.as_integer())
                    .map(|i| i as u64)
                    .or_else(|| cap.get("timeout").and_then(|v| v.as_integer()).map(|i| i as u64))
                    .unwrap_or(900);
                chosen = Some((binary, args, output, timeout));
                break 'outer;
            }
            index += 1;
        }
    }
    let (binary, raw_args, output, timeout) = chosen
        .ok_or_else(|| PlanError::InputValidation(format!("operation index {operation_index} out of range")))?;

    let catalog = get_catalog().ok_or(PlanError::Internal("catalog not initialized".into()))?;
    let base = catalog.get(&CapabilityId(id.to_string()))
        .ok_or_else(|| PlanError::CapabilityNotFound(id.to_string()))?;

    let resolved_inputs: BTreeMap<String, String> = base.inputs.iter().map(|spec| {
        let val = inputs.get(&spec.name).cloned().or(spec.default.clone()).unwrap_or_default();
        (spec.name.clone(), val)
    }).collect();

    let wordlist_override = inputs.get("wordlist").cloned();
    let registry = super::wordlists::WordlistRegistry::from_manifest().ok();
    let argv: Vec<String> = raw_args.iter().map(|arg| {
        let substituted = substitute_placeholders(arg, &resolved_inputs);
        substitute_wordlists(&substituted, wordlist_override.as_deref(), registry.as_ref())
    }).collect();

    let local_providers = ProviderRegistry::new();
    let binary_path = if base.native {
        PathBuf::from("(native)")
    } else {
        match local_providers.probe(&binary) {
            super::provider_registry::ProviderState::Available(ref path) => path.clone(),
            _ => PathBuf::from(&binary),
        }
    };
    let command_preview = format!("{} {}", binary, argv.join(" "));

    Ok(ExecutionPlan {
        job_id: JobId(format!("job_{}", uuid_like())),
        capability: base.id.clone(),
        provider: ProviderId(binary.clone()),
        binary_path,
        argv,
        env: BTreeMap::new(),
        cwd: PathBuf::from(scope.unwrap_or(".")),
        timeout: Duration::from_secs(timeout),
        retries: base.retry,
        parser: if output == "json" { "json".to_string() } else { base.parser.clone() },
        opsec: "balanced".into(),
        artifact_targets: base.artifacts.clone(),
        command_preview,
    })
}

/// Replace {wl:...} tokens with resolved absolute paths. A caller supplied
/// wordlist id overrides the catalog default for every token in the plan.
fn substitute_wordlists(
    arg: &str,
    override_id: Option<&str>,
    registry: Option<&super::wordlists::WordlistRegistry>,
) -> String {
    let mut result = arg.to_string();
    let mut start = 0usize;
    while let Some(rel) = result[start..].find("{wl:") {
        let abs = start + rel;
        let after = &result[abs + 4..];
        if let Some(end_rel) = after.find('}') {
            let end = abs + 4 + end_rel;
            let token_id = &result[abs + 4..end];
            let chosen = override_id.filter(|s| !s.is_empty()).unwrap_or(token_id);
            let replacement = registry
                .and_then(|r| r.resolve(chosen).ok())
                .map(|p| p.display().to_string())
                .unwrap_or_else(|| chosen.to_string());
            result.replace_range(abs..=end, &replacement);
            start = abs + replacement.len();
        } else {
            break;
        }
    }
    result
}

fn substitute_placeholders(arg: &str, inputs: &BTreeMap<String, String>) -> String {
    let mut result = arg.to_string();
    for (key, val) in inputs {
        let placeholder = format!("{{{}}}", key);
        result = result.replace(&placeholder, val);
    }
    result = result.replace("{artifacts}", "/tmp/loute_artifacts");
    result
}

fn uuid_like() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    format!("{:x}", now)
}
