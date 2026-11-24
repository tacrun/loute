// capability_catalog.rs - Load, hash-verify, and index the capability catalog.
// Per 1-5-5.md §8.1: asset bundle → SHA-256 verify → TOML parse → index.

use std::collections::HashMap;
use std::sync::Arc;

use super::capability_model::*;

pub struct CapabilityCatalog {
    pub capabilities: HashMap<CapabilityId, Capability>,
    pub by_phase: HashMap<Phase, Vec<CapabilityId>>,
    pub by_provider: HashMap<ProviderId, Vec<CapabilityId>>,
    /// All args across every provider operation, per capability. Used by V4/V5
    /// validation because placeholders may appear in operations beyond the first.
    pub all_args: HashMap<CapabilityId, Vec<String>>,
    pub hash: String,
    pub raw: String,
}

impl CapabilityCatalog {
    /// Load from a TOML string (the raw catalog content).
    pub fn from_toml(raw: &str) -> Result<Self, String> {
        let hash = sha256_hex(raw.as_bytes());

        // Parse with a lightweight TOML parser - we use toml crate
        let parsed: toml::Value = toml::from_str(raw)
            .map_err(|e| format!("TOML parse error: {}", e))?;

        let mut capabilities = HashMap::new();
        let mut by_phase: HashMap<Phase, Vec<CapabilityId>> = HashMap::new();
        let mut by_provider: HashMap<ProviderId, Vec<CapabilityId>> = HashMap::new();
        let mut all_args: HashMap<CapabilityId, Vec<String>> = HashMap::new();

        if let Some(caps) = parsed.get("capability").and_then(|v| v.as_array()) {
            for cap_val in caps {
                let cap = parse_capability(cap_val)?;
                let id = cap.id.clone();
                let phase = cap.phase;
                let provider = cap.provider.clone();

                // Collect args from every operation of every provider for V4/V5.
                let mut args_all = Vec::new();
                if let Some(providers) = cap_val.get("provider").and_then(|v| v.as_array()) {
                    for p in providers {
                        if let Some(ops) = p.get("operation").and_then(|v| v.as_array()) {
                            for op in ops {
                                if let Some(a) = op.get("args").and_then(|v| v.as_array()) {
                                    for v in a {
                                        if let Some(s) = v.as_str() {
                                            args_all.push(s.to_string());
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                // Also include flat schema-v2 args.
                if let Some(a) = cap_val.get("args").and_then(|v| v.as_array()) {
                    for v in a {
                        if let Some(s) = v.as_str() { args_all.push(s.to_string()); }
                    }
                }
                all_args.insert(id.clone(), args_all);

                capabilities.insert(id.clone(), cap);
                by_phase.entry(phase).or_default().push(id.clone());
                by_provider.entry(provider).or_default().push(id);
            }
        }

        Ok(Self {
            capabilities,
            by_phase,
            by_provider,
            all_args,
            hash,
            raw: raw.to_string(),
        })
    }

    pub fn get(&self, id: &CapabilityId) -> Option<&Capability> {
        self.capabilities.get(id)
    }

    pub fn by_phase(&self, phase: Phase) -> Vec<&Capability> {
        self.by_phase
            .get(&phase)
            .map(|ids| ids.iter().filter_map(|id| self.get(id)).collect())
            .unwrap_or_default()
    }

    pub fn all(&self) -> Vec<&Capability> {
        self.capabilities.values().collect()
    }

    pub fn count(&self) -> usize {
        self.capabilities.len()
    }

    pub fn count_by_phase(&self, phase: Phase) -> usize {
        self.by_phase.get(&phase).map(|v| v.len()).unwrap_or(0)
    }

    pub fn summaries(&self) -> Vec<CapabilitySummary> {
        self.capabilities
            .values()
            .map(|cap| CapabilitySummary {
                id: cap.id.clone(),
                phase: cap.phase,
                label: cap.label.clone(),
                summary: cap.summary.clone(),
                risk: cap.risk,
                noise: cap.noise,
                provider: cap.provider.clone(),
                native: cap.native,
                opsec_safe: cap.opsec_safe,
                availability: AvailabilityState::Probing,
            })
            .collect()
    }
}

fn parse_capability(val: &toml::Value) -> Result<Capability, String> {
    let id_str = val
        .get("id")
        .and_then(|v| v.as_str())
        .ok_or("missing id")?
        .to_string();

    let phase_str = val
        .get("phase")
        .and_then(|v| v.as_str())
        .unwrap_or("recon");
    let phase = Phase::from_str(phase_str).ok_or(format!("unknown phase: {phase_str}"))?;

    let label = val
        .get("label")
        .and_then(|v| v.as_str())
        .unwrap_or(&id_str)
        .to_string();

    let summary = val
        .get("summary")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();

    // Parse inputs
    let inputs = val
        .get("inputs")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|iv| {
                    let name = iv.get("key").or(iv.get("name"))?.as_str()?.to_string();
                    let kind_str = iv
                        .get("type")
                        .or(iv.get("kind"))
                        .and_then(|v| v.as_str())
                        .unwrap_or("text");
                    let required = iv
                        .get("required")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(false);
                    let default = iv
                        .get("default")
                        .and_then(|v| v.as_str())
                        .map(|s| s.to_string());
                    Some(InputSpec {
                        name,
                        kind: InputKind::from_str(kind_str),
                        required,
                        default,
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    // Parse provider - schema v1 uses [[capability.provider]] blocks
    // For the catalog, we take the first provider + first operation
    let (provider, binary, operation, args, output, probe, timeout) =
        if let Some(providers) = val.get("provider").and_then(|v| v.as_array()) {
            if providers.is_empty() {
                (ProviderId("native".into()), "native".into(), "default".into(), vec![], OutputMode::Lines, vec![], 900u64)
            } else {
                let p = &providers[0];
                let binary = p
                    .get("binary")
                    .and_then(|v| v.as_str())
                    .unwrap_or("native")
                    .to_string();
                let provider_id = ProviderId(binary.clone());

                let operations = p.get("operation").and_then(|v| v.as_array());
                let (operation, args, output_mode) = if let Some(ops) = operations {
                    if ops.is_empty() {
                        ("default".into(), Vec::new(), OutputMode::Lines)
                    } else {
                        let op = &ops[0];
                        let op_name = op
                            .get("name")
                            .and_then(|v| v.as_str())
                            .unwrap_or("default")
                            .to_string();
                        let op_args = op
                            .get("args")
                            .and_then(|v| v.as_array())
                            .map(|a| {
                                a.iter()
                                    .filter_map(|v| v.as_str().map(|s| s.to_string()))
                                    .collect::<Vec<_>>()
                            })
                            .unwrap_or_default();
                        let out = match op
                            .get("output")
                            .and_then(|v| v.as_str())
                            .unwrap_or("lines")
                        {
                            "json" => OutputMode::Json,
                            _ => OutputMode::Lines,
                        };
                        (op_name, op_args, out)
                    }
                } else {
                    ("default".into(), Vec::new(), OutputMode::Lines)
                };

                let probe = p
                    .get("probe")
                    .and_then(|v| v.as_array())
                    .map(|a| {
                        a.iter()
                            .filter_map(|v| v.as_str().map(|s| s.to_string()))
                            .collect()
                    })
                    .unwrap_or_default();

                let timeout = val
                    .get("timeout")
                    .and_then(|v| v.as_integer())
                    .map(|i| i as u64)
                    .unwrap_or(900);

                (provider_id, binary, operation, args, output_mode, probe, timeout)
            }
        } else {
            // Schema v2 style - flat provider/binary/args
            let binary = val
                .get("binary")
                .and_then(|v| v.as_str())
                .unwrap_or("native")
                .to_string();
            let provider_id = ProviderId(
                val.get("provider")
                    .and_then(|v| v.as_str())
                    .unwrap_or(&binary)
                    .to_string(),
            );
            let operation = val
                .get("operation")
                .and_then(|v| v.as_str())
                .unwrap_or("default")
                .to_string();
            let args = val
                .get("args")
                .and_then(|v| v.as_array())
                .map(|a| {
                    a.iter()
                        .filter_map(|v| v.as_str().map(|s| s.to_string()))
                        .collect()
                })
                .unwrap_or_default();
            let output_mode = match val
                .get("output")
                .and_then(|v| v.as_str())
                .unwrap_or("lines")
            {
                "json" => OutputMode::Json,
                _ => OutputMode::Lines,
            };
            let probe = val
                .get("probe")
                .and_then(|v| v.as_array())
                .map(|a| {
                    a.iter()
                        .filter_map(|v| v.as_str().map(|s| s.to_string()))
                        .collect()
                })
                .unwrap_or_default();
            let timeout = val
                .get("timeout")
                .and_then(|v| v.as_integer())
                .map(|i| i as u64)
                .unwrap_or(900);
            (provider_id, binary, operation, args, output_mode, probe, timeout)
        };

    // Parse schema 2 extended fields (with defaults for schema 1 compatibility)
    let risk = val
        .get("risk")
        .and_then(|v| v.as_str())
        .map(RiskTier::from_str)
        .unwrap_or(RiskTier::R1);

    let noise = val
        .get("noise")
        .and_then(|v| v.as_str())
        .and_then(NoiseLevel::from_str)
        .unwrap_or(NoiseLevel::Medium);

    let mitre = val
        .get("mitre")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().map(|s| MitreId(s.to_string())))
                .collect()
        })
        .unwrap_or_default();

    let platforms = val
        .get("platforms")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().and_then(Platform::from_str))
                .collect()
        })
        .unwrap_or_else(|| vec![Platform::Linux, Platform::Android, Platform::Windows]);

    let privileges = val
        .get("privileges")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().and_then(PrivilegeReq::from_str))
                .collect()
        })
        .unwrap_or_else(|| vec![PrivilegeReq::None]);

    let network = val
        .get("network")
        .and_then(|v| v.as_bool())
        .unwrap_or(true);

    let requires = val
        .get("requires")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().map(|s| CapabilityId(s.to_string())))
                .collect()
        })
        .unwrap_or_default();

    let provides = val
        .get("provides")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default();

    let line_schema = val.get("line_schema").map(|ls| LineSchema {
        kind: ls
            .get("kind")
            .and_then(|v| v.as_str())
            .unwrap_or("subdomain")
            .to_string(),
        fields: ls
            .get("fields")
            .and_then(|v| v.as_array())
            .map(|a| {
                a.iter()
                    .filter_map(|v| v.as_str().map(|s| s.to_string()))
                    .collect()
            })
            .unwrap_or_default(),
    });

    let parser = val
        .get("parser")
        .and_then(|v| v.as_str())
        .unwrap_or("lines")
        .to_string();

    let retry = val
        .get("retry")
        .and_then(|v| v.as_integer())
        .map(|i| i as u8)
        .unwrap_or(1);

    let concurrency = val
        .get("concurrency")
        .and_then(|v| v.as_integer())
        .map(|i| i as u8)
        .unwrap_or(4);

    let cache_ttl = val
        .get("cache_ttl")
        .and_then(|v| v.as_integer())
        .map(|i| i as u64)
        .unwrap_or(0);

    let artifacts = val
        .get("artifacts")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_else(|| vec!["text".into()]);

    let reversible = val
        .get("reversible")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    let cleanup = val
        .get("cleanup")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(|s| CapabilityId(s.to_string()));

    let chains = val
        .get("chains")
        .and_then(|v| v.as_array())
        .map(|a| {
            a.iter()
                .filter_map(|v| v.as_str().map(|s| CapabilityId(s.to_string())))
                .collect()
        })
        .unwrap_or_default();

    let opsec_safe = val
        .get("opsec_safe")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    let native = val
        .get("native")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    let schema = val
        .get("schema")
        .and_then(|v| v.as_integer())
        .map(|i| i as u8)
        .unwrap_or(1);

    let shell_escape = val
        .get("shell_escape")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);

    Ok(Capability {
        schema,
        id: CapabilityId(id_str),
        phase,
        label,
        summary,
        risk,
        noise,
        mitre,
        platforms,
        privileges,
        network,
        requires,
        provides,
        inputs,
        provider,
        binary,
        operation,
        args,
        output,
        line_schema,
        parser,
        probe,
        timeout,
        retry,
        concurrency,
        cache_ttl,
        artifacts,
        reversible,
        cleanup,
        chains,
        opsec_safe,
        native,
        shell_escape,
    })
}

/// Compute SHA-256 hex of a byte slice.
pub fn sha256_hex(data: &[u8]) -> String {
    // Minimal SHA-256 implementation (no external dependency needed)
    sha256_compute(data)
}

// ── SHA-256 implementation ──

const SHA256_K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

fn sha256_compute(data: &[u8]) -> String {
    let mut h: [u32; 8] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];

    let len = data.len();
    let bit_len = (len as u64) * 8;

    // Padding
    let mut padded = data.to_vec();
    padded.push(0x80);
    while padded.len() % 64 != 56 {
        padded.push(0);
    }
    padded.extend_from_slice(&bit_len.to_be_bytes());

    // Process blocks
    for chunk in padded.chunks(64) {
        let mut w = [0u32; 64];
        for i in 0..16 {
            w[i] = u32::from_be_bytes([
                chunk[i * 4],
                chunk[i * 4 + 1],
                chunk[i * 4 + 2],
                chunk[i * 4 + 3],
            ]);
        }
        for i in 16..64 {
            let s0 = w[i - 15].rotate_right(7) ^ w[i - 15].rotate_right(18) ^ (w[i - 15] >> 3);
            let s1 = w[i - 2].rotate_right(17) ^ w[i - 2].rotate_right(19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16].wrapping_add(s0).wrapping_add(w[i - 7]).wrapping_add(s1);
        }

        let mut a = h[0];
        let mut b = h[1];
        let mut c = h[2];
        let mut d = h[3];
        let mut e = h[4];
        let mut f = h[5];
        let mut g = h[6];
        let mut hh = h[7];

        for i in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let ch = (e & f) ^ ((!e) & g);
            let temp1 = hh.wrapping_add(s1).wrapping_add(ch).wrapping_add(SHA256_K[i]).wrapping_add(w[i]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let maj = (a & b) ^ (a & c) ^ (b & c);
            let temp2 = s0.wrapping_add(maj);

            hh = g;
            g = f;
            f = e;
            e = d.wrapping_add(temp1);
            d = c;
            c = b;
            b = a;
            a = temp1.wrapping_add(temp2);
        }

        h[0] = h[0].wrapping_add(a);
        h[1] = h[1].wrapping_add(b);
        h[2] = h[2].wrapping_add(c);
        h[3] = h[3].wrapping_add(d);
        h[4] = h[4].wrapping_add(e);
        h[5] = h[5].wrapping_add(f);
        h[6] = h[6].wrapping_add(g);
        h[7] = h[7].wrapping_add(hh);
    }

    h.iter().map(|v| format!("{:08x}", v)).collect()
}

// Static catalog singleton
use std::sync::OnceLock;

static CATALOG: OnceLock<Arc<CapabilityCatalog>> = OnceLock::new();

pub fn init_catalog(raw: &str) -> Result<(), String> {
    let catalog = Arc::new(CapabilityCatalog::from_toml(raw)?);
    let _ = CATALOG.set(catalog);
    Ok(())
}

pub fn get_catalog() -> Option<&'static Arc<CapabilityCatalog>> {
    CATALOG.get()
}
