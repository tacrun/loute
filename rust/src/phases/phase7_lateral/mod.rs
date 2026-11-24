// phase7_lateral/mod.rs — LATERAL phase (26 capabilities)
// Capability IDs mirror the shipped catalog (capabilities.toml.txt, schema v1).
// Per 1-5-5.md §10 phase modules.

use crate::core::capability_model::*;

pub struct Phase7Lateral;

impl Phase7Lateral {
    /// Catalog-accurate capability IDs for this phase.
    pub fn capabilities() -> Vec<&'static str> {
        vec![
            "network-discovery",
            "service-enumeration",
            "smb-pivot",
            "winrm-pivot",
            "rdp-pivot",
            "ssh-pivot",
            "ntlm-relay",
            "arp-spoof",
            "llmnr-nbtns-poison",
            "port-forward",
            "socks-pivot",
            "mssql-pivot",
            "session-hijack",
            "internal-web-pivot",
            "vpn-internal-access",
            "ad-recon",
            "adcs-abuse",
            "dns-internal-recon",
            "wmi-pivot",
            "credential-reuse-pivot",
            "packet-capture-pivot",
            "coercion-trigger",
            "firewall-rule-recon",
            "lateral-map-report",
            "dns-discovery",
            "share-harvest",
        ]
    }

    pub fn phase() -> Phase { Phase::Lateral }

    pub fn count() -> usize { 26 }
}
