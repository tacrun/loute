// phase10_wireless/mod.rs — WIRELESS phase (21 capabilities)
// Capability IDs mirror the shipped catalog (capabilities.toml.txt, schema v1).
// Per 1-5-5.md §10 phase modules.

use crate::core::capability_model::*;

pub struct Phase10Wireless;

impl Phase10Wireless {
    /// Catalog-accurate capability IDs for this phase.
    pub fn capabilities() -> Vec<&'static str> {
        vec![
            "interface-setup",
            "monitor-capture",
            "ap-discovery",
            "handshake-capture",
            "pmkid-attack",
            "deauth-testing",
            "evil-twin",
            "wpa-crack",
            "wep-crack",
            "wps-attacks",
            "wpa3-dragonfly",
            "bt-recon",
            "iot-ble-sweep",
            "captive-portal",
            "rogue-dhcp",
            "wifi-mitm",
            "packet-analysis",
            "spectrum-survey",
            "probe-privacy",
            "isolation-testing",
            "audit-reporting",
        ]
    }

    pub fn phase() -> Phase { Phase::Wireless }

    pub fn count() -> usize { 21 }
}
