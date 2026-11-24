// phase2_surface/mod.rs — ATTACK SURFACE phase (22 capabilities)
// Capability IDs mirror the shipped catalog (capabilities.toml.txt, schema v1).
// Per 1-5-5.md §10 phase modules.

use crate::core::capability_model::*;

pub struct Phase2Surface;

impl Phase2Surface {
    /// Catalog-accurate capability IDs for this phase.
    pub fn capabilities() -> Vec<&'static str> {
        vec![
            "port-discovery",
            "service-fingerprint",
            "host-discovery",
            "web-profiling",
            "api-discovery",
            "vhost-enumeration",
            "content-discovery",
            "parameter-discovery",
            "tls-analysis",
            "endpoint-mapping",
            "container-exposure",
            "database-exposure",
            "network-profiling",
            "asset-correlation",
            "directory-bruteforce",
            "cloud-exposure",
            "http-misconfig",
            "ldap-enum",
            "smb-enum",
            "mail-surface",
            "iot-surface",
            "vpn-surface",
        ]
    }

    pub fn phase() -> Phase { Phase::Surface }

    pub fn count() -> usize { 22 }
}
