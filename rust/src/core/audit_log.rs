// audit_log.rs — Hash-chained append-only log per 1-5-5.md §6.12.
// Each record carries prev_hash. Fields: ts, actor, workspace, job, capability,
// argv, provider version, catalog hash, exit code, artifact hashes, finding ids.

use std::path::PathBuf;
use std::sync::Mutex;

use super::capability_catalog::sha256_hex;
use super::capability_model::*;

pub struct AuditLog {
    log_path: PathBuf,
    records: Mutex<Vec<AuditRecord>>,
    last_hash: Mutex<String>,
}

impl AuditLog {
    pub fn new(workspace_id: &WorkspaceId) -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
        let dir = PathBuf::from(home)
            .join(".local/share/loute/workspaces")
            .join(&workspace_id.0);
        std::fs::create_dir_all(&dir).ok();
        let log_path = dir.join("audit.jsonl");

        // Load existing records to continue the hash chain
        let mut records = Vec::new();
        let mut last_hash = String::new();
        if let Ok(content) = std::fs::read_to_string(&log_path) {
            for line in content.lines() {
                if line.is_empty() {
                    continue;
                }
                if let Ok(record) = serde_json::from_str::<AuditRecord>(line) {
                    last_hash = record.record_hash.clone();
                    records.push(record);
                }
            }
        }

        Self {
            log_path,
            records: Mutex::new(records),
            last_hash: Mutex::new(last_hash),
        }
    }

    pub fn record(
        &self,
        actor: &str,
        workspace: Option<&WorkspaceId>,
        job: Option<&JobId>,
        capability: Option<&CapabilityId>,
        argv: &[String],
        provider_version: &str,
        catalog_hash: &str,
        exit_code: Option<i32>,
        artifact_hashes: &[String],
        finding_ids: &[String],
    ) -> AuditRecord {
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let prev_hash = self.last_hash.lock().unwrap().clone();

        // Compute record hash
        let hash_input = format!(
            "{}|{}|{}|{}|{:?}|{}|{}|{:?}|{:?}|{:?}",
            timestamp, actor,
            workspace.map(|w| w.0.as_str()).unwrap_or(""),
            job.map(|j| j.0.as_str()).unwrap_or(""),
            argv,
            provider_version, catalog_hash,
            exit_code,
            artifact_hashes,
            finding_ids
        );
        let record_hash = sha256_hex(hash_input.as_bytes());

        let record = AuditRecord {
            timestamp,
            actor: actor.to_string(),
            workspace: workspace.cloned(),
            job: job.cloned(),
            capability: capability.cloned(),
            argv: argv.to_vec(),
            provider_version: provider_version.to_string(),
            catalog_hash: catalog_hash.to_string(),
            exit_code,
            artifact_hashes: artifact_hashes.to_vec(),
            finding_ids: finding_ids.to_vec(),
            prev_hash: prev_hash.clone(),
            record_hash: record_hash.clone(),
        };

        // Append to file
        let line = serde_json::to_string(&record).unwrap_or_default();
        if let Ok(mut file) = std::fs::OpenOptions::new()
            .append(true)
            .create(true)
            .open(&self.log_path)
        {
            use std::io::Write;
            let _ = writeln!(file, "{}", line);
        }

        // Update state
        *self.last_hash.lock().unwrap() = record_hash;
        self.records.lock().unwrap().push(record.clone());

        record
    }

    pub fn list(&self) -> Vec<AuditRecord> {
        self.records.lock().unwrap().clone()
    }
}
