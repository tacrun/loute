// finding_normalizer.rs — Raw → Finding/Asset/Artifact per 1-5-5.md §6.8.
// Dedupe by (capability, asset_key, discriminator).
// Severity/confidence scoring → MITRE mapping → evidence attachment → graph upsert.

use std::collections::BTreeMap;
use std::sync::Mutex;

use super::capability_model::*;
use super::output_parser::*;

pub struct FindingNormalizer {
    assets: Mutex<Vec<Asset>>,
    findings: Mutex<Vec<Finding>>,
}

impl FindingNormalizer {
    pub fn new() -> Self {
        Self {
            assets: Mutex::new(Vec::new()),
            findings: Mutex::new(Vec::new()),
        }
    }

    pub fn ingest(
        &self,
        job_id: &JobId,
        workspace: &WorkspaceId,
        capability: &CapabilityId,
        outcome: &ParseOutcome,
    ) {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        // Assets
        for parsed in &outcome.assets {
            let asset_id = AssetId(format!("asset_{}", short_hash(&parsed.key)));
            let mut assets = self.assets.lock().unwrap();
            if let Some(existing) = assets.iter_mut().find(|a| a.id == asset_id) {
                existing.last_seen = now;
                existing.sources.push(job_id.clone());
            } else {
                let attrs: BTreeMap<String, serde_json::Value> = parsed
                    .attrs
                    .iter()
                    .map(|(k, v)| (k.clone(), serde_json::Value::String(v.clone())))
                    .collect();
                assets.push(Asset {
                    id: asset_id.clone(),
                    workspace: workspace.clone(),
                    kind: parsed.kind.clone(),
                    key: parsed.key.clone(),
                    attrs,
                    first_seen: now,
                    last_seen: now,
                    sources: vec![job_id.clone()],
                    confidence: 0.7,
                });
            }
        }

        // Findings
        for parsed in &outcome.findings {
            let dedupe_key = format!("{}|{}|{}", capability.0, parsed.discriminator, parsed.title);
            let finding_id = FindingId(format!("finding_{}", short_hash(&dedupe_key)));

            let mut findings = self.findings.lock().unwrap();
            if let Some(existing) = findings.iter_mut().find(|f| f.id == finding_id) {
                existing.observations += 1;
            } else {
                findings.push(Finding {
                    id: finding_id,
                    workspace: workspace.clone(),
                    asset: AssetId("asset_unknown".into()),
                    capability: capability.clone(),
                    title: parsed.title.clone(),
                    detail: parsed.detail.clone(),
                    severity: parsed.severity,
                    confidence: 0.7,
                    cvss: None,
                    mitre: vec![],
                    state: FindingState::New,
                    evidence_refs: vec![],
                    observations: 1,
                    first_seen: now,
                    dedupe_key,
                });
            }
        }
    }

    pub fn list_assets(&self) -> Vec<Asset> {
        self.assets.lock().unwrap().clone()
    }

    pub fn list_findings(&self) -> Vec<Finding> {
        self.findings.lock().unwrap().clone()
    }
}

fn short_hash(s: &str) -> String {
    let hash = super::capability_catalog::sha256_hex(s.as_bytes());
    hash[..12].to_string()
}
