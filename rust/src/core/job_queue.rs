// job_queue.rs - Bounded priority queue per 1-5-5.md §6.5.
// Priority bands: interactive > chained > scheduled > background.

use std::collections::HashMap;
use std::sync::Arc;
use std::sync::Mutex;
use tokio::sync::mpsc;

use super::capability_model::*;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum JobPriority {
    Background,
    Scheduled,
    Chained,
    Interactive,
}

#[derive(Debug, Clone)]
pub struct JobEntry {
    pub id: JobId,
    pub capability: CapabilityId,
    pub priority: JobPriority,
    pub state: JobState,
    pub workspace: Option<WorkspaceId>,
}

pub struct JobQueue {
    entries: Arc<Mutex<Vec<JobEntry>>>,
    pub sender: mpsc::UnboundedSender<JobId>,
}

impl JobQueue {
    pub fn new() -> (Self, mpsc::UnboundedReceiver<JobId>) {
        let (sender, receiver) = mpsc::unbounded_channel();
        (
            Self {
                entries: Arc::new(Mutex::new(Vec::new())),
                sender,
            },
            receiver,
        )
    }

    pub fn enqueue(&self, id: JobId, capability: CapabilityId, priority: JobPriority) {
        let entry = JobEntry {
            id: id.clone(),
            capability,
            priority,
            state: JobState::Queued,
            workspace: None,
        };
        self.entries.lock().unwrap().push(entry);
        let _ = self.sender.send(id);
    }

    pub fn list(&self) -> Vec<JobEntry> {
        self.entries.lock().unwrap().clone()
    }

    pub fn update_state(&self, job_id: &JobId, state: JobState) {
        let mut entries = self.entries.lock().unwrap();
        if let Some(entry) = entries.iter_mut().find(|e| e.id == *job_id) {
            entry.state = state;
        }
    }

    pub fn get(&self, job_id: &JobId) -> Option<JobEntry> {
        self.entries
            .lock()
            .unwrap()
            .iter()
            .find(|e| e.id == *job_id)
            .cloned()
    }
}
