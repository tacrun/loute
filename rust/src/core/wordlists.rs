// wordlists.rs — {wl:} resolution and integrity per 1-5-5.md §14.
// {wl:dns/subdomains-top1m} → manifest lookup → hash verify → absolute path → argv.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::Mutex;

pub struct WordlistEntry {
    pub id: String,
    pub path: PathBuf,
    pub lines: u64,
    pub bytes: u64,
    pub sha256: String,
    pub pack: String,
}

pub struct WordlistRegistry {
    entries: Mutex<HashMap<String, WordlistEntry>>,
}

impl WordlistRegistry {
    pub fn new() -> Self {
        Self {
            entries: Mutex::new(HashMap::new()),
        }
    }

    /// Load the shipped resource manifest (resources/manifest.toml). Searches upward
    /// from the current dir so it works from crate root, workspace root and Flutter dir.
    pub fn from_manifest() -> Result<Self, String> {
        let mut reg = Self::new();
        let candidates = [
            "resources/manifest.toml",
            "../resources/manifest.toml",
            "../../resources/manifest.toml",
        ];
        let mut found: Option<PathBuf> = None;
        for c in candidates {
            let p = PathBuf::from(c);
            if p.exists() { found = Some(p); break; }
        }
        let path = found.ok_or("resources/manifest.toml not found")?;
        let base = path.parent().unwrap_or(std::path::Path::new(".")).to_path_buf();
        let raw = std::fs::read_to_string(&path).map_err(|e| e.to_string())?;
        let value: toml::Value = toml::from_str(&raw).map_err(|e| format!("manifest TOML error: {}", e))?;
        if let Some(arr) = value.get("wordlist").and_then(|v| v.as_array()) {
            for w in arr {
                let id = w.get("id").and_then(|v| v.as_str()).ok_or("wordlist missing id")?.to_string();
                let rel = w.get("path").and_then(|v| v.as_str()).unwrap_or("");
                let sha = w.get("sha256").and_then(|v| v.as_str()).unwrap_or("").to_string();
                let pack = w.get("pack").and_then(|v| v.as_str()).unwrap_or("core").to_string();
                reg.register(WordlistEntry {
                    id,
                    path: base.join(rel),
                    lines: w.get("lines").and_then(|v| v.as_integer()).unwrap_or(0) as u64,
                    bytes: w.get("bytes").and_then(|v| v.as_integer()).unwrap_or(0) as u64,
                    sha256: sha,
                    pack,
                });
            }
        }
        Ok(reg)
    }

    /// Resolve and verify content hash against the manifest (§14.3).
    pub fn resolve_verified(&self, id: &str) -> Result<PathBuf, String> {
        let path = self.resolve(id)?;
        let entries = self.entries.lock().unwrap();
        if let Some(e) = entries.get(id) {
            if !e.sha256.is_empty() {
                let bytes = std::fs::read(&path).map_err(|e| e.to_string())?;
                let actual = crate::core::capability_catalog::sha256_hex(&bytes);
                if actual != e.sha256 {
                    return Err(format!("wordlist integrity mismatch: {} (expected {}, got {})", id, e.sha256, actual));
                }
            }
        }
        Ok(path)
    }

    pub fn register(&self, entry: WordlistEntry) {
        self.entries.lock().unwrap().insert(entry.id.clone(), entry);
    }

    /// Resolve a {wl:} reference to a file path.
    /// Returns Err if the wordlist is not in the manifest or the file is missing.
    pub fn resolve(&self, id: &str) -> Result<PathBuf, String> {
        let entries = self.entries.lock().unwrap();
        let entry = entries
            .get(id)
            .ok_or_else(|| format!("wordlist not in manifest: {}", id))?;

        if !entry.path.exists() {
            return Err(format!(
                "wordlist file missing: {} (pack: {})",
                entry.path.display(),
                entry.pack
            ));
        }

        Ok(entry.path.clone())
    }

    pub fn list(&self) -> Vec<WordlistStatus> {
        let entries = self.entries.lock().unwrap();
        entries
            .values()
            .map(|e| WordlistStatus {
                id: e.id.clone(),
                path: e.path.display().to_string(),
                lines: e.lines,
                bytes: e.bytes,
                exists: e.path.exists(),
                pack: e.pack.clone(),
            })
            .collect()
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct WordlistStatus {
    pub id: String,
    pub path: String,
    pub lines: u64,
    pub bytes: u64,
    pub exists: bool,
    pub pack: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn loads_shipped_manifest() {
        let reg = WordlistRegistry::from_manifest().expect("manifest must load");
        let list = reg.list();
        assert!(list.len() >= 36, "manifest should contain >= 36 wordlists, got {}", list.len());
        for w in &list {
            assert!(w.exists, "wordlist file missing: {}", w.id);
        }
    }

    #[test]
    fn resolves_and_verifies_hash() {
        let reg = WordlistRegistry::from_manifest().expect("manifest must load");
        let p = reg.resolve_verified("dns/hostnames.txt").expect("must resolve and verify");
        assert!(p.exists());
        assert!(reg.resolve_verified("does/not/exist.txt").is_err());
    }
}
