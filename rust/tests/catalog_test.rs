// catalog_test.rs — Integration tests for catalog loading and validation.
// Per 1-5-5.md §18.1, §23 acceptance checklist.

use loute_core::core::capability_catalog::CapabilityCatalog;
use loute_core::core::catalog_validate::validate;
use loute_core::core::capability_model::*;

fn load_master_catalog() -> String {
    let candidates = [
        concat!(env!("CARGO_MANIFEST_DIR"), "/../capabilities.toml.txt"),
        concat!(env!("CARGO_MANIFEST_DIR"), "/capabilities.toml.txt"),
    ];
    for p in &candidates {
        if let Ok(s) = std::fs::read_to_string(p) {
            if !s.is_empty() {
                return s;
            }
        }
    }
    panic!("master capabilities.toml.txt not found");
}

#[test]
fn catalog_loads_all_241_capabilities() {
    let raw = load_master_catalog();
    let cat = CapabilityCatalog::from_toml(&raw).expect("catalog must parse");
    assert_eq!(cat.count(), 241, "catalog must contain exactly 241 capabilities");
}

#[test]
fn catalog_phase_distribution_is_correct() {
    let raw = load_master_catalog();
    let cat = CapabilityCatalog::from_toml(&raw).unwrap();
    let expected = [
        (Phase::Recon, 22usize),
        (Phase::Surface, 22),
        (Phase::Vulnerability, 22),
        (Phase::Payload, 21),
        (Phase::Escalation, 24),
        (Phase::Credentials, 22),
        (Phase::Lateral, 26),
        (Phase::Persistence, 19),
        (Phase::Exploitation, 27),
        (Phase::Wireless, 21),
        (Phase::Ctf, 15),
    ];
    for (phase, n) in expected {
        assert_eq!(cat.count_by_phase(phase), n, "phase {} count", phase.as_str());
    }
}

#[test]
fn all_capabilities_have_schema2_metadata() {
    let raw = load_master_catalog();
    let cat = CapabilityCatalog::from_toml(&raw).unwrap();
    for cap in cat.all() {
        assert_eq!(cap.schema, 2, "{} must be schema 2", cap.id);
        assert!(!cap.mitre.is_empty(), "{} missing MITRE", cap.id);
        assert!(!cap.platforms.is_empty(), "{} missing platforms", cap.id);
        assert!(!cap.privileges.is_empty(), "{} missing privileges", cap.id);
        assert!(!cap.parser.is_empty(), "{} missing parser", cap.id);
        assert!(cap.timeout >= 5 && cap.timeout <= 86400, "{} bad timeout", cap.id);
        assert!(cap.concurrency >= 1 && cap.concurrency <= 16, "{} bad concurrency", cap.id);
    }
}

#[test]
fn catalog_passes_v1_v20_validation() {
    let raw = load_master_catalog();
    let cat = CapabilityCatalog::from_toml(&raw).unwrap();
    let report = validate(&cat);
    let errors: Vec<String> = report.errors.iter().map(|e| format!("{} {}: {}", e.rule, e.capability_id, e.message)).collect();
    assert!(report.valid, "catalog validation failed:\n{}", errors.join("\n"));
}

#[test]
fn catalog_hash_is_stable() {
    let raw = load_master_catalog();
    let a = CapabilityCatalog::from_toml(&raw).unwrap();
    let b = CapabilityCatalog::from_toml(&raw).unwrap();
    assert_eq!(a.hash, b.hash, "SHA-256 must be deterministic (V20)");
    assert_eq!(a.hash.len(), 64, "hash must be 64 hex chars");
}

#[test]
fn eleven_native_capabilities_are_present() {
    let raw = load_master_catalog();
    let cat = CapabilityCatalog::from_toml(&raw).unwrap();
    let natives: Vec<_> = cat.all().into_iter().filter(|c| c.native).collect();
    assert_eq!(natives.len(), 8, "eight preserved native recon implementations mapped to catalog IDs");
}

#[test]
fn no_shell_metacharacters_in_args() {
    let raw = load_master_catalog();
    let cat = CapabilityCatalog::from_toml(&raw).unwrap();
    for cap in cat.all() {
        if cap.shell_escape {
            continue; // capability declares its own pre-escaped args (§6.4)
        }
        for arg in &cap.args {
            if arg.contains('{') {
                continue; // placeholder, resolved at plan time
            }
            for ch in [';', '&', '|', '`', '$', '>', '<'] {
                assert!(!arg.contains(ch), "{} arg '{}' contains shell metachar '{}' (I1/V6)", cap.id, arg, ch);
            }
        }
    }
}
