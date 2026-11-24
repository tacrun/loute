// provider_registry.rs - Provider binary allowlist and version ranges.
// provider_probe.rs - Availability probes per 1-5-5.md §6.6.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use super::capability_model::AvailabilityState;

#[derive(Debug, Clone)]
pub enum ProviderState {
    Available(PathBuf),
    Missing,
    VersionMismatch(String),
    PermissionDenied,
    InterfaceMissing,
    Degraded(String),
    Probing,
}

pub struct ProviderRegistry {
    states: Mutex<HashMap<String, (ProviderState, Instant)>>,
}

impl ProviderRegistry {
    pub fn new() -> Self {
        Self {
            states: Mutex::new(HashMap::new()),
        }
    }

    /// All distinct provider binaries in the shipped catalog (native excluded).
    pub fn known_binaries(&self) -> Vec<String> {
        use super::capability_catalog::get_catalog;
        let mut bins: Vec<String> = get_catalog()
            .map(|c| c.capabilities.values().map(|cap| cap.binary.clone())
                .filter(|b| b != "native" && !b.is_empty())
                .collect())
            .unwrap_or_default();
        bins.sort();
        bins.dedup();
        bins
    }

    /// Probe a provider binary - check if it exists in PATH.
    pub fn probe(&self, binary: &str) -> ProviderState {
        // Native providers are always "available"
        if binary == "native" || binary == "(native)" {
            return ProviderState::Available(PathBuf::from("(native)"));
        }

        // Check cache (10 min TTL)
        {
            let states = self.states.lock().unwrap();
            if let Some((state, checked_at)) = states.get(binary) {
                if checked_at.elapsed() < Duration::from_secs(600) {
                    return state.clone();
                }
            }
        }

        // Probe: check if binary exists in PATH
        let state = self.do_probe(binary);

        // Cache result
        {
            let mut states = self.states.lock().unwrap();
            states.insert(binary.to_string(), (state.clone(), Instant::now()));
        }

        state
    }

    fn do_probe(&self, binary: &str) -> ProviderState {
        // Use `which` equivalent - check common PATH locations
        let path_var = std::env::var("PATH").unwrap_or_default();
        let path_dirs: Vec<&str> = path_var.split(':').collect();

        for dir in &path_dirs {
            let candidate = PathBuf::from(dir).join(binary);
            if candidate.exists() {
                // Check if executable
                if let Ok(metadata) = std::fs::metadata(&candidate) {
                    if metadata.is_file() {
                        // Try to get version
                        return ProviderState::Available(candidate);
                    }
                }
            }
        }

        ProviderState::Missing
    }

    /// Get the AvailabilityState for a capability summary.
    pub fn availability(&self, binary: &str) -> AvailabilityState {
        match self.probe(binary) {
            ProviderState::Available(_) => AvailabilityState::Available,
            ProviderState::Missing => AvailabilityState::Missing,
            ProviderState::VersionMismatch(_) => AvailabilityState::VersionMismatch,
            ProviderState::PermissionDenied => AvailabilityState::PermissionDenied,
            ProviderState::InterfaceMissing => AvailabilityState::InterfaceMissing,
            ProviderState::Degraded(_) => AvailabilityState::Degraded,
            ProviderState::Probing => AvailabilityState::Probing,
        }
    }

    /// Force re-probe (invalidate cache).
    pub fn invalidate(&self, binary: &str) {
        let mut states = self.states.lock().unwrap();
        states.remove(binary);
    }

    /// Invalidate all cached states.
    pub fn invalidate_all(&self) {
        let mut states = self.states.lock().unwrap();
        states.clear();
    }

    /// Probe all known providers and return a matrix.
    pub fn probe_all(&self, binaries: &[String]) -> Vec<ProviderSummary> {
        binaries
            .iter()
            .map(|b| {
                let state = self.probe(b);
                let version = if let ProviderState::Available(ref path) = state {
                    self.get_version(path)
                } else {
                    None
                };
                ProviderSummary {
                    name: b.clone(),
                    binary: b.clone(),
                    state: self.availability(b),
                    version,
                    capability_count: 0,
                    install_hint: Some(format!("Install {} to enable related capabilities", b)),
                }
            })
            .collect()
    }

    fn get_version(&self, path: &PathBuf) -> Option<String> {
        // Try to run --version with a short timeout
        let output = std::process::Command::new(path)
            .arg("--version")
            .output();

        match output {
            Ok(out) if out.status.success() => {
                let stdout = String::from_utf8_lossy(&out.stdout);
                stdout.lines().next().map(|s| s.to_string())
            }
            _ => {
                // Try -V
                let output = std::process::Command::new(path)
                    .arg("-V")
                    .output();
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
}

// Re-export ProviderSummary from capability_model
pub use super::capability_model::ProviderSummary;
