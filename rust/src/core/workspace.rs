// workspace.rs — Workspace lifecycle per 1-5-5.md §6.10.
// create_workspace(name, kind) where kind ∈ engagement|lab|ctf|research.

use std::sync::Mutex;
use std::collections::HashMap;

use super::capability_model::*;

pub struct WorkspaceManager {
    workspaces: Mutex<HashMap<WorkspaceId, Workspace>>,
}

impl WorkspaceManager {
    pub fn new() -> Self {
        Self {
            workspaces: Mutex::new(HashMap::new()),
        }
    }

    pub fn create(&self, name: &str, kind: WorkspaceKind) -> WorkspaceId {
        let id = WorkspaceId(format!("ws_{}", short_id()));
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let ws = Workspace {
            id: id.clone(),
            name: name.to_string(),
            kind,
            created_at: now,
        };
        self.workspaces.lock().unwrap().insert(id.clone(), ws);
        id
    }

    pub fn get(&self, id: &WorkspaceId) -> Option<Workspace> {
        self.workspaces.lock().unwrap().get(id).cloned()
    }

    pub fn list(&self) -> Vec<Workspace> {
        self.workspaces.lock().unwrap().values().cloned().collect()
    }
}

fn short_id() -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos();
    format!("{:x}", now)
}
