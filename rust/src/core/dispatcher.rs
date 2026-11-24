// dispatcher.rs — CapabilityId → ExecutionPlan per 1-5-5.md §6.3.
// Performs: catalog lookup → input validation → placeholder substitution →
// wordlist resolution → provider resolution → availability check → argv materialization.

use std::collections::BTreeMap;
use std::path::PathBuf;

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
                    // Still plan it — execution will handle the missing provider
                    PathBuf::from(&cap.binary)
                }
            }
        };

        // Argv materialization — substitute {placeholder} values
        let argv: Vec<String> = cap
            .args
            .iter()
            .map(|arg| substitute_placeholders(arg, &resolved_inputs))
            .collect();

        // Command preview — byte-identical to argv
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

fn substitute_placeholders(arg: &str, inputs: &BTreeMap<String, String>) -> String {
    let mut result = arg.to_string();
    for (key, val) in inputs {
        let placeholder = format!("{{{}}}", key);
        result = result.replace(&placeholder, val);
    }
    // Resolve {wl:...} placeholders — for now just leave the path reference
    // In full implementation this would look up the wordlist manifest
    // {artifacts} → temp dir
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
