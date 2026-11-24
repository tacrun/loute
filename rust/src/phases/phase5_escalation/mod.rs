// phase5_escalation/mod.rs - ESCALATION phase (24 capabilities)
// Capability IDs mirror the shipped catalog (capabilities.toml.txt, schema v1).
// Per 1-5-5.md §10 phase modules.

use crate::core::capability_model::*;

pub struct Phase5Escalation;

impl Phase5Escalation {
    /// Catalog-accurate capability IDs for this phase.
    pub fn capabilities() -> Vec<&'static str> {
        vec![
            "suid-hunting",
            "sudo-misconfig",
            "cron-abuse",
            "service-exploit",
            "path-hijack",
            "capability-abuse",
            "kernel-exploit",
            "container-escape",
            "password-harvest",
            "ssh-key-harvest",
            "windows-service-hijack",
            "token-impersonation",
            "writable-file-abuse",
            "environment-leak",
            "nfs-squash",
            "smb-share-privilege",
            "database-cred-exfil",
            "web-root-write",
            "log-poisoning",
            "dns-zone-privilege",
            "git-repo-privilege",
            "kerberos-privilege",
            "privilege-audit",
            "remote-code-exec",
        ]
    }

    pub fn phase() -> Phase { Phase::Escalation }

    pub fn count() -> usize { 24 }
}
