// phase4_payload/mod.rs — PAYLOAD phase (21 capabilities)
// Capability IDs mirror the shipped catalog (capabilities.toml.txt, schema v1).
// Per 1-5-5.md §10 phase modules.

use crate::core::capability_model::*;

pub struct Phase4Payload;

impl Phase4Payload {
    /// Catalog-accurate capability IDs for this phase.
    pub fn capabilities() -> Vec<&'static str> {
        vec![
            "shellcode-generation",
            "payload-encoding",
            "binary-weaponization",
            "macro-crafting",
            "implant-building",
            "stager-creation",
            "dropper-packaging",
            "artifact-obfuscation",
            "binary-analysis",
            "c2-configuration",
            "evasion-testing",
            "staging-server",
            "delivery-preparation",
            "payload-validation",
            "payload-testing",
            "listener-deployment",
            "registry-persistence",
            "linux-persistence",
            "webshell-deployment",
            "dns-c2",
            "payload-delivery",
        ]
    }

    pub fn phase() -> Phase { Phase::Payload }

    pub fn count() -> usize { 21 }
}
