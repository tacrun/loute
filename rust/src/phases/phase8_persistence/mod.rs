// phase8_persistence/mod.rs — PERSISTENCE phase (19 capabilities)
// Capability IDs mirror the shipped catalog (capabilities.toml.txt, schema v1).
// Per 1-5-5.md §10 phase modules.

use crate::core::capability_model::*;

pub struct Phase8Persistence;

impl Phase8Persistence {
    /// Catalog-accurate capability IDs for this phase.
    pub fn capabilities() -> Vec<&'static str> {
        vec![
            "cron-persistence",
            "systemd-persistence",
            "shell-profile-persistence",
            "ssh-authorized-keys",
            "registry-run-keys",
            "scheduled-task-windows",
            "wmi-subscription",
            "startup-folder",
            "service-persistence-linux",
            "webshell-persistence",
            "dns-persistence",
            "cloud-persistence",
            "backdoor-user",
            "ldaps-persistence",
            "wireless-rogue-ap",
            "macro-autorun-persistence",
            "persistence-audit",
            "persistence-teardown",
            "persistence-verification",
        ]
    }

    pub fn phase() -> Phase { Phase::Persistence }

    pub fn count() -> usize { 19 }
}
