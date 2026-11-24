// artifact_store.rs — Content-addressed writes per 1-5-5.md §6.9.
// ~/.local/share/loute/workspaces/<ws>/artifacts/<sha256[0:2]>/<sha256>
// Write is atomic (temp + rename). Nothing is ever overwritten.

use std::path::PathBuf;
use std::sync::Mutex;

use super::capability_catalog::sha256_hex;
use super::capability_model::*;

pub struct ArtifactStore {
    base_dir: PathBuf,
    index: Mutex<Vec<Artifact>>,
}

impl ArtifactStore {
    pub fn new(workspace_id: &WorkspaceId) -> Self {
        let base = artifact_base_dir(workspace_id);
        std::fs::create_dir_all(&base).ok();
        Self {
            base_dir: base,
            index: Mutex::new(Vec::new()),
        }
    }

    /// Write content to the artifact store. Returns the artifact metadata.
    pub fn write(
        &self,
        content: &[u8],
        media_type: &str,
        job: &JobId,
    ) -> std::io::Result<Artifact> {
        let hash = sha256_hex(content);
        let prefix = &hash[..2];
        let dir = self.base_dir.join(prefix);
        std::fs::create_dir_all(&dir)?;

        let path = dir.join(&hash);

        // Atomic write: temp file + rename
        if !path.exists() {
            let tmp = dir.join(format!("{}.tmp", hash));
            std::fs::write(&tmp, content)?;
            std::fs::rename(&tmp, &path)?;
        }

        // Write sidecar .meta.json
        let meta_path = dir.join(format!("{}.meta.json", hash));
        let meta = serde_json::json!({
            "sha256": hash,
            "media_type": media_type,
            "bytes": content.len(),
            "job": job.0,
            "created_at": std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
        });
        std::fs::write(&meta_path, serde_json::to_string_pretty(&meta).unwrap())?;

        let artifact = Artifact {
            id: ArtifactId(hash.clone()),
            sha256: hash,
            media_type: media_type.to_string(),
            bytes: content.len() as u64,
            path,
            job: job.clone(),
            created_at: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs(),
        };

        self.index.lock().unwrap().push(artifact.clone());

        Ok(artifact)
    }

    pub fn list(&self) -> Vec<Artifact> {
        self.index.lock().unwrap().clone()
    }

    pub fn read(&self, id: &ArtifactId) -> Option<Vec<u8>> {
        let prefix = &id.0[..2];
        let path = self.base_dir.join(prefix).join(&id.0);
        std::fs::read(&path).ok()
    }
}

fn artifact_base_dir(workspace_id: &WorkspaceId) -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(home)
        .join(".local/share/loute/workspaces")
        .join(&workspace_id.0)
        .join("artifacts")
}
