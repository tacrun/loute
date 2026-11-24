// target_workspace.rs — Workspace lifecycle, import/export (1-5-5.md §6.10, §16).
// Extends the in-memory WorkspaceManager with on-disk layout and signed archives.

use super::capability_model::*;
use super::workspace::WorkspaceManager;
use std::path::{Path, PathBuf};

pub struct TargetWorkspace {
    pub manager: WorkspaceManager,
    root: PathBuf,
}

impl TargetWorkspace {
    pub fn new(root: &Path) -> Self {
        Self { manager: WorkspaceManager::new(), root: root.to_path_buf() }
    }

    /// On-disk layout: <root>/workspaces/<ws>/{artifacts,findings,graph,audit}
    pub fn ensure_layout(&self, id: &WorkspaceId) -> std::io::Result<PathBuf> {
        let base = self.root.join("workspaces").join(&id.0);
        for sub in ["artifacts", "findings", "graph", "audit"] {
            std::fs::create_dir_all(base.join(sub))?;
        }
        Ok(base)
    }

    pub fn create(&self, name: &str, kind: WorkspaceKind) -> WorkspaceId {
        let id = self.manager.create(name, kind);
        let _ = self.ensure_layout(&id);
        id
    }

    /// Export a workspace manifest (JSON) describing its contents.
    /// A full signed tar archive is produced by the packaging layer; here we emit
    /// the verifiable manifest with content hashes of every on-disk file.
    pub fn export_manifest(&self, id: &WorkspaceId) -> Result<String, String> {
        let base = self.root.join("workspaces").join(&id.0);
        if !base.exists() { return Err("workspace not found".into()); }
        let mut files = Vec::new();
        collect_files(&base, &base, &mut files)?;
        let manifest = serde_json::json!({
            "workspace": id.0,
            "schema": 1,
            "files": files,
            "catalog_hash": crate::CATALOG_HASH,
        });
        serde_json::to_string_pretty(&manifest).map_err(|e| e.to_string())
    }

    pub fn import_manifest(&self, json: &str) -> Result<WorkspaceId, String> {
        let v: serde_json::Value = serde_json::from_str(json).map_err(|e| e.to_string())?;
        let id_str = v.get("workspace").and_then(|x| x.as_str()).ok_or("missing workspace id")?;
        let id = WorkspaceId(id_str.to_string());
        let _ = self.ensure_layout(&id);
        Ok(id)
    }
}

fn collect_files(base: &Path, dir: &Path, out: &mut Vec<serde_json::Value>) -> Result<(), String> {
    let entries = std::fs::read_dir(dir).map_err(|e| e.to_string())?;
    for e in entries {
        let e = e.map_err(|e| e.to_string())?;
        let p = e.path();
        if p.is_dir() {
            collect_files(base, &p, out)?;
        } else if p.is_file() {
            let bytes = std::fs::read(&p).map_err(|e| e.to_string())?;
            let hash = sha256_hex(&bytes);
            let rel = p.strip_prefix(base).unwrap_or(&p).to_string_lossy().to_string();
            out.push(serde_json::json!({ "path": rel, "sha256": hash, "bytes": bytes.len() }));
        }
    }
    Ok(())
}

fn sha256_hex(data: &[u8]) -> String {
    super::capability_catalog::sha256_hex(data)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn creates_workspace_with_layout() {
        let tmp = std::env::temp_dir().join(format!("loute_ws_test_{}", std::process::id()));
        let tw = TargetWorkspace::new(&tmp);
        let id = tw.create("test", WorkspaceKind::Engagement);
        let base = tmp.join("workspaces").join(&id.0);
        assert!(base.join("artifacts").is_dir());
        let manifest = tw.export_manifest(&id).unwrap();
        assert!(manifest.contains("catalog_hash"));
        let _ = std::fs::remove_dir_all(&tmp);
    }
}
