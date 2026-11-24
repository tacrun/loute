// phase6_credentials/mod.rs — CREDENTIALS phase (22 capabilities)
// Capability IDs mirror the shipped catalog (capabilities.toml.txt, schema v1).
// Per 1-5-5.md §10 phase modules.

use crate::core::capability_model::*;

pub struct Phase6Credentials;

impl Phase6Credentials {
    /// Catalog-accurate capability IDs for this phase.
    pub fn capabilities() -> Vec<&'static str> {
        vec![
            "hash-identification",
            "hash-cracking",
            "ntlm-dump",
            "smb-auth-spray",
            "http-auth-brute",
            "service-login-brute",
            "kerberoast",
            "wifi-handshake-crack",
            "ssh-key-crack",
            "zip-archive-crack",
            "credential-dump-linux",
            "windows-credential-sweep",
            "keystores-cert-pull",
            "browser-password-extract",
            "secret-scan-filesystem",
            "cloud-credential-probe",
            "jwt-token-audit",
            "database-cred-test",
            "credential-reuse-test",
            "wordlist-preparation",
            "wireless-credential-audit",
            "hash-extraction-pcap",
        ]
    }

    pub fn phase() -> Phase { Phase::Credentials }

    pub fn count() -> usize { 22 }
}
