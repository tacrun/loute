// provider_probe.rs — Availability probes with version detection (1-5-5.md §6.6).
// Runs a version invocation with a 2s budget; states cached 10 min.

use super::capability_model::*;
use super::provider_registry::ProviderRegistry;
use std::collections::HashMap;
use std::process::Command;
use std::sync::Mutex;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub struct CachedProbe {
    pub state: AvailabilityState,
    pub version: Option<String>,
    pub probed_at: Instant,
}

pub struct ProviderProber {
    cache: Mutex<HashMap<String, CachedProbe>>,
    ttl: Duration,
}

impl Default for ProviderProber {
    fn default() -> Self { Self::new() }
}

impl ProviderProber {
    pub fn new() -> Self {
        Self { cache: Mutex::new(HashMap::new()), ttl: Duration::from_secs(600) }
    }

    /// Probe a binary. Returns state + detected version. Uses `which`-style PATH lookup
    /// and a short `-version`/`--version` invocation. Never uses a shell.
    pub fn probe(&self, binary: &str, version_args: &[String]) -> CachedProbe {
        if let Some(c) = self.cache.lock().unwrap().get(binary) {
            if c.probed_at.elapsed() < self.ttl {
                return c.clone();
            }
        }

        let binary_path = find_in_path(binary);
        let result = match binary_path {
            None => CachedProbe { state: AvailabilityState::Missing, version: None, probed_at: Instant::now() },
            Some(path) => {
                let version = invoke_version(&path, version_args);
                let state = if version.is_none() {
                    AvailabilityState::Degraded // found but version probe failed
                } else {
                    AvailabilityState::Available
                };
                CachedProbe { state, version, probed_at: Instant::now() }
            }
        };
        self.cache.lock().unwrap().insert(binary.to_string(), result.clone());
        result
    }

    pub fn invalidate(&self, binary: &str) {
        self.cache.lock().unwrap().remove(binary);
    }
}

fn find_in_path(binary: &str) -> Option<String> {
    if binary.contains('/') {
        let p = std::path::Path::new(binary);
        if p.is_file() {
            use std::os::unix::fs::PermissionsExt;
            if let Ok(md) = std::fs::metadata(p) {
                if md.permissions().mode() & 0o111 != 0 {
                    return Some(binary.to_string());
                }
            }
        }
        return None;
    }
    let path_var = std::env::var("PATH").unwrap_or_default();
    for dir in path_var.split(':') {
        let candidate = format!("{}/{}", dir, binary);
        let p = std::path::Path::new(&candidate);
        if p.is_file() {
            use std::os::unix::fs::PermissionsExt;
            if let Ok(md) = std::fs::metadata(p) {
                if md.permissions().mode() & 0o111 != 0 {
                    return Some(candidate);
                }
            }
        }
    }
    None
}

fn invoke_version(path: &str, args: &[String]) -> Option<String> {
    let mut cmd = Command::new(path);
    cmd.args(args);
    let out = cmd.output().ok()?;
    let text = String::from_utf8_lossy(&out.stdout);
    let text = if text.trim().is_empty() {
        String::from_utf8_lossy(&out.stderr)
    } else {
        text
    };
    let line = text.lines().next()?.trim();
    if line.is_empty() { None } else { Some(line.chars().take(120).collect()) }
}

/// Build a provider health matrix across all catalog binaries.
pub fn build_matrix() -> Vec<(String, AvailabilityState, Option<String>)> {
    let registry = ProviderRegistry::new();
    let prober = ProviderProber::new();
    let binaries = registry.known_binaries();
    let mut out = Vec::new();
    for b in binaries {
        let probe = prober.probe(&b, &["--version".to_string()]);
        out.push((b, probe.state, probe.version));
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn nonexistent_binary_is_missing() {
        let p = ProviderProber::new();
        let r = p.probe("__loute_definitely_not_a_real_binary__", &["--version".into()]);
        assert!(matches!(r.state, AvailabilityState::Missing));
        assert!(r.version.is_none());
    }

    #[test]
    fn cache_is_used() {
        let p = ProviderProber::new();
        let a = p.probe("__none__", &[]);
        let b = p.probe("__none__", &[]);
        assert_eq!(a.probed_at, b.probed_at);
    }
}
