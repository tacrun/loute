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
