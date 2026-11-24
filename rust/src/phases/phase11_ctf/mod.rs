// phase11_ctf/mod.rs - CTF phase (15 capabilities)
// Capability IDs mirror the shipped catalog (capabilities.toml.txt, schema v1).
// Per 1-5-5.md §10 phase modules.

use crate::core::capability_model::*;

pub struct Phase11Ctf;

impl Phase11Ctf {
    /// Catalog-accurate capability IDs for this phase.
    pub fn capabilities() -> Vec<&'static str> {
        vec![
            "web-app-security",
            "network-recon-service",
            "active-directory",
            "mobile-app-security",
            "cloud-security",
            "reverse-engineering",
            "binary-exploitation",
            "network-forensics",
            "digital-forensics",
            "cryptography",
            "steganography",
            "privilege-escalation",
            "wireless-iot",
            "scripting-misc",
            "flag-scanning",
        ]
    }

    pub fn phase() -> Phase { Phase::Ctf }

    pub fn count() -> usize { 15 }
}
