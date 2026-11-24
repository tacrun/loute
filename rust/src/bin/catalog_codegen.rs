// catalog_codegen.rs - Generates Flutter/tooling artifacts from the catalog.
// Regenerates: capability_index.dart, capability_index.json, wordlist_index.dart,
// mitre_coverage.md, provider_matrix.md. Idempotent.

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::PathBuf;

/// Locate the master catalog.
fn find_catalog() -> PathBuf {
    let candidates = [
        "capabilities.toml.txt",
        "../capabilities.toml.txt",
        "../../capabilities.toml.txt",
    ];
    for c in candidates {
        let p = PathBuf::from(c);
        if p.exists() { return p; }
    }
    panic!("capabilities.toml.txt not found");
}

/// Escape a value for a Dart single-quoted string literal.
fn esc(s: &str) -> String {
    s.replace('\\', "\\\\")
        .replace('\'', "\\'")
        .replace('\n', " ")
        .replace('\r', " ")
        .replace('$', "\\$")
}

fn arr(v: &toml::Value, key: &str) -> Vec<String> {
    v.get(key).and_then(|x| x.as_array())
        .map(|a| a.iter().filter_map(|x| x.as_str().map(|s| s.to_string())).collect())
        .unwrap_or_default()
}
fn strv(v: &toml::Value, key: &str, def: &str) -> String {
    v.get(key).and_then(|x| x.as_str()).unwrap_or(def).to_string()
}
fn boolv(v: &toml::Value, key: &str) -> bool {
    v.get(key).and_then(|x| x.as_bool()).unwrap_or(false)
}
fn intv(v: &toml::Value, key: &str, def: i64) -> i64 {
    v.get(key).and_then(|x| x.as_integer()).unwrap_or(def)
}

#[derive(serde::Serialize, Clone)]
struct Input {
    name: String, kind: String, required: bool, default: Option<String>, help: String,
}
#[derive(serde::Serialize, Clone)]
struct Operation {
    name: String, binary: String, args: Vec<String>, output: String,
    network: bool, stage: i64, probe: bool, timeout: i64,
}
#[derive(serde::Serialize, Clone)]
struct Cap {
    id: String, phase: String, label: String, summary: String,
    risk: String, noise: String, mitre: Vec<String>, platforms: Vec<String>,
    privileges: Vec<String>, network: bool, provider: String, binary: String,
    parser: String, timeout: i64, native: bool, reversible: bool,
    opsec_safe: bool, shell_escape: bool, inputs: Vec<Input>,
    operations: Vec<Operation>, provides: Vec<String>, requires: Vec<String>,
    chains: Vec<String>,
}

fn sl(v: &[String]) -> String {
    format!("const [{}]", v.iter().map(|x| format!("'{}'", esc(x))).collect::<Vec<_>>().join(", "))
}

fn main() {
    let catalog_path = find_catalog();
    let repo_root = catalog_path.parent().unwrap().to_path_buf();
    let raw = fs::read_to_string(&catalog_path).expect("read catalog");
    let value: toml::Value = toml::from_str(&raw).expect("parse catalog TOML");
    let caps_val = value.get("capability").and_then(|v| v.as_array()).expect("capability array");

    let mut all: Vec<Cap> = Vec::new();
    for c in caps_val {
        let mut operations = Vec::new();
        let mut first_binary = String::new();
        if let Some(providers) = c.get("provider").and_then(|p| p.as_array()) {
            for p in providers {
                let binary = strv(p, "binary", "native");
                if first_binary.is_empty() { first_binary = binary.clone(); }
                if let Some(ops) = p.get("operation").and_then(|o| o.as_array()) {
                    for op in ops {
                        operations.push(Operation {
                            name: strv(op, "name", "Run"),
                            binary: binary.clone(),
                            args: arr(op, "args"),
                            output: strv(op, "output", "lines"),
                            network: boolv(op, "network"),
                            stage: intv(op, "stage", 1),
                            probe: boolv(op, "probe"),
                            timeout: intv(op, "timeout", 0),
                        });
                    }
                }
            }
        }
        let binary = if first_binary.is_empty() { "native".to_string() } else { first_binary.clone() };
        let inputs = c.get("inputs").and_then(|v| v.as_array()).map(|a| a.iter().filter_map(|iv| {
            let name = iv.get("key").or(iv.get("name"))?.as_str()?;
            Some(Input {
                name: name.to_string(),
                kind: strv(iv, "type", &strv(iv, "kind", "text")),
                required: boolv(iv, "required"),
                default: iv.get("default").and_then(|v| v.as_str()).map(|s| s.to_string()),
                help: strv(iv, "help", ""),
            })
        }).collect()).unwrap_or_default();
        let provider_names: Vec<String> = c.get("provider").and_then(|p| p.as_array())
            .map(|a| a.iter().filter_map(|p| p.get("binary").and_then(|v| v.as_str()).map(|s| s.to_string())).collect())
            .unwrap_or_default();
        all.push(Cap {
            id: strv(c, "id", ""),
            phase: strv(c, "phase", "recon"),
            label: strv(c, "label", ""),
            summary: strv(c, "summary", ""),
            risk: strv(c, "risk", "R1"),
            noise: strv(c, "noise", "medium"),
            mitre: arr(c, "mitre"),
            platforms: arr(c, "platforms"),
            privileges: arr(c, "privileges"),
            network: boolv(c, "network"),
            provider: provider_names.join(","),
            binary,
            parser: strv(c, "parser", "lines"),
            timeout: intv(c, "timeout", 900),
            native: boolv(c, "native"),
            reversible: boolv(c, "reversible"),
            opsec_safe: boolv(c, "opsec_safe"),
            shell_escape: boolv(c, "shell_escape"),
            inputs,
            operations,
            provides: arr(c, "provides"),
            requires: arr(c, "requires"),
            chains: arr(c, "chains"),
        });
    }
    all.sort_by(|a, b| a.id.cmp(&b.id));

    // ---- 1. capability_index.json ----
    let index_json = serde_json::to_string_pretty(&serde_json::json!({
        "schema": 3,
        "count": all.len(),
        "catalog_sha256": loute_core::CATALOG_HASH,
        "capabilities": all,
    })).expect("serialize json");
    fs::write(repo_root.join("loute/assets/capabilities/capability_index.json"), format!("{}\n", index_json)).expect("write json");

    // ---- 2. capability_index.dart ----
    let mut dart = String::new();
    dart.push_str("// capability_index.dart - GENERATED by cargo run --bin catalog_codegen.\n");
    dart.push_str("// DO NOT EDIT. Source: capabilities.toml.txt.\n");
    dart.push_str(&format!("// LOUTE V1.5.5 | 11 phases | {} capabilities | hash {}\n\n", all.len(), loute_core::CATALOG_HASH));

    dart.push_str("enum LoutePhase { recon, surface, vulnerability, payload, escalation, credentials, lateral, persistence, exploitation, wireless, ctf;\n");
    dart.push_str("  String get displayName {\n    switch (this) {\n");
    for (p, d) in [("recon","RECONNAISSANCE"),("surface","ATTACK SURFACE"),("vulnerability","VULNERABILITY"),("payload","PAYLOAD"),("escalation","ESCALATION"),("credentials","CREDENTIALS"),("lateral","LATERAL"),("persistence","PERSISTENCE"),("exploitation","EXPLOITATION"),("wireless","WIRELESS"),("ctf","CTF CHALLENGES")] {
        dart.push_str(&format!("      case {}: return '{}';\n", p, d));
    }
    dart.push_str("    }\n  }\n\n");
    dart.push_str("  String get shortName {\n    switch (this) {\n");
    for (p, d) in [("recon","Recon"),("surface","Surface"),("vulnerability","Vulns"),("payload","Payload"),("escalation","Escalation"),("credentials","Credentials"),("lateral","Lateral"),("persistence","Persistence"),("exploitation","Exploitation"),("wireless","Wireless"),("ctf","CTF")] {
        dart.push_str(&format!("      case {}: return '{}';\n", p, d));
    }
    dart.push_str("    }\n  }\n\n");
    dart.push_str("  int get order => LoutePhase.values.indexOf(this);\n");
    dart.push_str("  static LoutePhase fromString(String s) => LoutePhase.values.firstWhere(\n    (p) => p.name == s.toLowerCase(), orElse: () => LoutePhase.recon);\n}\n\n");

    dart.push_str("enum LouteRisk { r0, r1, r2, r3, r4 }\n");
    dart.push_str("enum LouteNoise { silent, low, medium, high, screaming }\n\n");

    dart.push_str("class CapInputDef {\n  final String key, type, help, defaultValue;\n  final bool required;\n  const CapInputDef({\n    required this.key, required this.type, required this.help,\n    required this.defaultValue, required this.required,\n  });\n}\n\n");
    dart.push_str("class CapOperation {\n  final String name, binary, output;\n  final List<String> args;\n  final bool network, probe;\n  final int stage, timeout;\n  const CapOperation({\n    required this.name, required this.binary, required this.output,\n    required this.args, required this.network, required this.probe,\n    required this.stage, required this.timeout,\n  });\n}\n\n");
    dart.push_str("class CapabilityEntry {\n  final String id, phase, label, summary, risk, noise, provider, binary, parser;\n  final List<String> mitre, platforms, privileges, provides, requires, chains;\n  final bool network, native, reversible, opsecSafe, shellEscape;\n  final int timeout;\n  final List<CapInputDef> inputs;\n  final List<CapOperation> operations;\n  const CapabilityEntry({\n    required this.id, required this.phase, required this.label, required this.summary,\n    required this.risk, required this.noise, required this.provider, required this.binary,\n    required this.parser, required this.mitre, required this.platforms, required this.privileges,\n    required this.provides, required this.requires, required this.chains, required this.network,\n    required this.native, required this.reversible, required this.opsecSafe,\n    required this.shellEscape, required this.timeout,\n    required this.inputs, required this.operations,\n  });\n\n  LoutePhase get phaseEnum => LoutePhase.fromString(phase);\n  List<String> get binaries {\n    final seen = <String>{};\n    for (final op in operations) { seen.add(op.binary); }\n    return seen.toList();\n  }\n}\n\n");

    dart.push_str(&format!("const String kCatalogHash = '{}';\nconst int kCapabilityCount = {};\n\n", loute_core::CATALOG_HASH, all.len()));
    dart.push_str("const List<CapabilityEntry> kCapabilities = [\n");
    for c in &all {
        let inputs = c.inputs.iter().map(|i| format!(
            "CapInputDef(key: '{}', type: '{}', help: '{}', defaultValue: '{}', required: {})",
            esc(&i.name), esc(&i.kind), esc(&i.help), esc(i.default.as_deref().unwrap_or("")), i.required
        )).collect::<Vec<_>>().join(", ");
        let ops = c.operations.iter().map(|o| format!(
            "CapOperation(name: '{}', binary: '{}', output: '{}', args: {}, network: {}, probe: {}, stage: {}, timeout: {})",
            esc(&o.name), esc(&o.binary), esc(&o.output), sl(&o.args), o.network, o.probe, o.stage, o.timeout
        )).collect::<Vec<_>>().join(", ");
        dart.push_str(&format!(
            "  CapabilityEntry(id: '{}', phase: '{}', label: '{}', summary: '{}', risk: '{}', noise: '{}', provider: '{}', binary: '{}', parser: '{}', mitre: {}, platforms: {}, privileges: {}, provides: {}, requires: {}, chains: {}, network: {}, native: {}, reversible: {}, opsecSafe: {}, shellEscape: {}, timeout: {}, inputs: const [{}], operations: const [{}]),\n",
            esc(&c.id), esc(&c.phase), esc(&c.label), esc(&c.summary), esc(&c.risk), esc(&c.noise),
            esc(&c.provider), esc(&c.binary), esc(&c.parser), sl(&c.mitre), sl(&c.platforms), sl(&c.privileges),
            sl(&c.provides), sl(&c.requires), sl(&c.chains), c.network, c.native, c.reversible, c.opsec_safe, c.shell_escape, c.timeout,
            inputs, ops
        ));
    }
    dart.push_str("];\n\n");
    dart.push_str("CapabilityEntry? findCapability(String id) {\n  for (final c in kCapabilities) { if (c.id == id) return c; }\n  return null;\n}\n");
    dart.push_str("List<CapabilityEntry> byPhase(String phase) => kCapabilities.where((c) => c.phase == phase).toList();\n");
    dart.push_str("List<CapabilityEntry> byPhaseEnum(LoutePhase phase) => byPhase(phase.name);\n\n");
    // CatalogMeta helpers retained from the user's generated file so regeneration is idempotent.
    dart.push_str("class CatalogMeta {\n");
    dart.push_str("  static const String version = '1.5.5';\n");
    dart.push_str("  static int get totalCapabilities => kCapabilities.length;\n");
    dart.push_str("  static int get totalPhases => LoutePhase.values.length;\n");
    dart.push_str("  static Map<String, int> get phaseCounts {\n    final counts = <String, int>{};\n    for (final c in kCapabilities) { counts[c.phase] = (counts[c.phase] ?? 0) + 1; }\n    return counts;\n  }\n}\n");
    fs::write(repo_root.join("loute/lib/generated/capability_index.dart"), dart).expect("write dart");

    // ---- 3. wordlist_index.dart ----
    // Discover every shipped category dynamically so the index always matches
    // what is actually present under resources/wordlists.
    let cat_labels: BTreeMap<&str, &str> = [
        ("passwords", "Passwords"), ("creds", "Credentials"),
        ("users", "Usernames"), ("usernames", "Usernames"),
        ("dns", "DNS"), ("web", "Web Content"), ("http", "HTTP"),
        ("dirs", "Directories"), ("params", "Parameters"), ("payloads", "Payloads"),
        ("wifi", "Wireless"), ("wireless", "Wireless"),
        ("ssh", "SSH"), ("smb", "SMB"), ("ad", "Active Directory"),
        ("db", "Databases"), ("fuzz", "Fuzzing"), ("rules", "Rules"),
        ("cloud", "Cloud"), ("mobile", "Mobile"), ("ctf", "CTF"),
    ].into_iter().collect();
    let wl_dir = repo_root.join("resources/wordlists");
    let mut categories: Vec<String> = Vec::new();
    if let Ok(entries) = fs::read_dir(&wl_dir) {
        for e in entries.flatten() {
            let p = e.path();
            if p.is_dir() {
                categories.push(p.file_name().unwrap().to_string_lossy().to_string());
            }
        }
    }
    categories.sort();

    let mut wl = String::new();
    wl.push_str("// wordlist_index.dart - GENERATED from resources/wordlists.\n");
    wl.push_str("// DO NOT EDIT.\n\n");
    wl.push_str("class WordlistEntry {\n  final String id, category, path, label;\n  const WordlistEntry({required this.id, required this.category, required this.path, required this.label});\n}\n\n");
    wl.push_str("const Map<String, String> kWordlistCategoryLabels = {\n");
    for cat in &categories {
        let label = cat_labels.get(cat.as_str()).copied().unwrap_or(cat.as_str());
        wl.push_str(&format!("  '{}': '{}',\n", cat, label));
    }
    wl.push_str("};\n\n");
    wl.push_str("const List<WordlistEntry> kWordlists = [\n");
    let mut wl_count = 0usize;
    for cat in &categories {
        let d = wl_dir.join(cat);
        let mut files: Vec<PathBuf> = fs::read_dir(&d).into_iter().flatten()
            .filter_map(|e| e.ok()).map(|e| e.path())
            .filter(|p| p.is_file()).collect();
        files.sort();
        for f in files {
            let name = f.file_name().unwrap().to_string_lossy().to_string();
            let id = format!("{}/{}", cat, name);
            let label = name.replace('-', " ").replace('_', " ").replace(".txt", "").replace(".rule", "").to_uppercase();
            wl.push_str(&format!("  WordlistEntry(id: '{}', category: '{}', path: '{}', label: '{}'),\n",
                esc(&id), esc(cat), esc(&id), esc(&label)));
            wl_count += 1;
        }
    }
    wl.push_str("];\n\n");
    wl.push_str("List<WordlistEntry> wordlistsForCategory(String category) =>\n  kWordlists.where((w) => w.category == category).toList();\n");
    fs::write(repo_root.join("loute/lib/generated/wordlist_index.dart"), wl).expect("write wordlist dart");
    println!("  wordlists indexed: {} across {} categories", wl_count, categories.len());

    // ---- 4. mitre_coverage.md ----
    let mut mitre: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for c in &all { for t in &c.mitre { mitre.entry(t.clone()).or_default().push(c.id.clone()); } }
    let mut md = format!("# MITRE ATT&CK Coverage\n\nGenerated from `capabilities.toml.txt`. {} unique techniques across {} capabilities.\n\n", mitre.len(), all.len());
    md.push_str("| Technique | Capabilities | Count |\n|---|---|---|\n");
    for (t, ids) in &mitre {
        md.push_str(&format!("| `{}` | {} | {} |\n", t, ids.iter().take(5).map(|x| format!("`{}`", x)).collect::<Vec<_>>().join(", "), ids.len()));
    }
    fs::write(repo_root.join("docs/mitre_coverage.md"), md).expect("write mitre md");

    // ---- 5. provider_matrix.md ----
    let mut providers: BTreeMap<String, usize> = BTreeMap::new();
    for c in &all {
        let mut seen = BTreeSet::new();
        for op in &c.operations { seen.insert(op.binary.clone()); }
        for b in seen { *providers.entry(b).or_default() += 1; }
    }
    let mut pm = format!("# Provider Matrix\n\nGenerated from `capabilities.toml.txt`. {} distinct provider binaries.\n\n", providers.len());
    pm.push_str("| Binary | Capabilities |\n|---|---|\n");
    let mut sorted: Vec<_> = providers.iter().collect();
    sorted.sort_by(|a, b| b.1.cmp(a.1).then(a.0.cmp(b.0)));
    for (b, n) in sorted { pm.push_str(&format!("| `{}` | {} |\n", b, n)); }
    fs::write(repo_root.join("docs/provider_matrix.md"), pm).expect("write provider md");

    println!("Generated 5 artifacts from {} capabilities (hash {})", all.len(), loute_core::CATALOG_HASH);

    let _ = BTreeSet::<String>::new();
}
