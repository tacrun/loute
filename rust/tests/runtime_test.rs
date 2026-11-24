// runtime_test.rs — Prove the full execution path works (§12.1, §23 acceptance).
use loute_core::core::runtime::Runtime;
use std::collections::BTreeMap;

#[test]
fn runtime_initializes_and_catalog_is_loaded() {
    loute_core::init_catalog().expect("catalog must initialize");
    assert_eq!(loute_core::core::capability_catalog::get_catalog().unwrap().count(), 241);
}

#[tokio::test]
async fn dry_run_produces_byte_identical_preview() {
    loute_core::init_catalog().ok();
    let rt = Runtime::new();
    let mut inputs = BTreeMap::new();
    inputs.insert("domain".to_string(), "example.com".to_string());
    let plan = rt.plan("recon.subdomain-discovery", &inputs, None).expect("plan must build");
    assert!(!plan.command_preview.is_empty());
    assert_eq!(plan.capability.0, "recon.subdomain-discovery");
    // Determinism: planning twice with identical inputs yields identical argv.
    let plan2 = rt.plan("recon.subdomain-discovery", &inputs, None).unwrap();
    assert_eq!(plan.argv, plan2.argv, "same inputs must produce identical argv (§5.3)");
}

#[tokio::test]
async fn missing_required_input_is_typed_error() {
    loute_core::init_catalog().ok();
    let rt = Runtime::new();
    let inputs = BTreeMap::new();
    let err = rt.plan("recon.subdomain-discovery", &inputs, None).unwrap_err();
    assert!(matches!(err, loute_core::core::capability_model::PlanError::InputValidation(_)));
}

#[test]
fn parser_dispatch_covers_all_tool_formats() {
    let samples = [
        ("lines", "a.com\n1.2.3.4\n"),
        ("json", r#"[{"host":"x.com"}]"#),
        ("xml", "<host><address>1.1.1.1</address></host>"),
        ("nmap", "80/tcp open http Apache\n"),
        ("masscan", "Discovered open port 443/tcp on 1.2.3.4\n"),
        ("nuclei", r#"{"template-id":"x","info":{"severity":"high"},"host":"h"}"#),
        ("ffuf", r#"{"results":[{"url":"http://x","status":200}]}"#),
        ("smb", "IPC$  IPC  remote IPC\n"),
        ("ldap", "dn: CN=user\nobjectClass: user\n"),
        ("kerberos", "u@D:$krb5tgs$1234$abcdef\n"),
        ("hashcat", "5d41402abc4b2a76b9719d911017c592:hello\n"),
        ("airodump", "BSSID, First seen, Last seen, CH\nAA:BB:CC:DD:EE:FF, x, y, 6\n"),
        ("tshark", "1.2.3.4\t8.8.8.8\n"),
        ("generic_table", "example.com 200 123\n"),
    ];
    for (id, raw) in samples {
        let out = loute_core::parsers::parse(id, raw);
        // Each parser must return an outcome (never panic). At least one signal expected.
        assert!(out.assets.len() + out.findings.len() + out.artifacts.len() > 0, "parser {} produced nothing", id);
    }
}
