// job_registry.rs — Live job table and cancellation tree (1-5-5.md §6.1, §12.5).
// Cancel tree per workspace → job → process group. Orphan reaper on startup.

use super::capability_model::*;
use std::collections::{HashMap, HashSet};
use std::sync::{Arc, Mutex};

#[derive(Debug, Clone)]
pub struct JobHandle {
    pub id: JobId,
    pub workspace: Option<WorkspaceId>,
    pub state: JobState,
    pub pid: Option<u32>,
    pub cancel_requested: Option<CancelMode>,
}

pub struct JobRegistry {
    jobs: Arc<Mutex<HashMap<JobId, JobHandle>>>,
    /// Map from OS process-group id to job, for group cancellation.
    process_groups: Arc<Mutex<HashMap<i32, JobId>>>,
}

impl Default for JobRegistry {
    fn default() -> Self { Self::new() }
}

impl JobRegistry {
    pub fn new() -> Self {
        Self {
            jobs: Arc::new(Mutex::new(HashMap::new())),
            process_groups: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn register(&self, id: JobId, workspace: Option<WorkspaceId>) {
        self.jobs.lock().unwrap().entry(id.clone()).or_insert(JobHandle {
            id,
            workspace,
            state: JobState::Queued,
            pid: None,
            cancel_requested: None,
        });
    }

    pub fn set_state(&self, id: &JobId, state: JobState) {
        if let Some(j) = self.jobs.lock().unwrap().get_mut(id) {
            j.state = state;
        }
    }

    pub fn attach_process(&self, id: &JobId, pid: u32, pgid: i32) {
        if let Some(j) = self.jobs.lock().unwrap().get_mut(id) {
            j.pid = Some(pid);
        }
        self.process_groups.lock().unwrap().insert(pgid, id.clone());
    }

    pub fn detach_process(&self, id: &JobId) {
        if let Some(j) = self.jobs.lock().unwrap().get_mut(id) {
            j.pid = None;
        }
        let mut pg = self.process_groups.lock().unwrap();
        pg.retain(|_, v| v != id);
    }

    /// Request cancellation. Graceful: SIGINT then SIGKILL after 5s; Force: immediate.
    pub fn request_cancel(&self, id: &JobId, mode: CancelMode) -> bool {
        if let Some(j) = self.jobs.lock().unwrap().get_mut(id) {
            j.cancel_requested = Some(mode);
            true
        } else {
            false
        }
    }

    pub fn cancel_requested(&self, id: &JobId) -> Option<CancelMode> {
        self.jobs.lock().unwrap().get(id).and_then(|j| j.cancel_requested)
    }

    pub fn get(&self, id: &JobId) -> Option<JobHandle> {
        self.jobs.lock().unwrap().get(id).cloned()
    }

    pub fn job_for_pgid(&self, pgid: i32) -> Option<JobId> {
        self.process_groups.lock().unwrap().get(&pgid).cloned()
    }

    pub fn by_workspace(&self, ws: &WorkspaceId) -> Vec<JobHandle> {
        self.jobs.lock().unwrap().values()
            .filter(|j| j.workspace.as_ref() == Some(ws))
            .cloned().collect()
    }

    pub fn list(&self) -> Vec<JobHandle> {
        self.jobs.lock().unwrap().values().cloned().collect()
    }

    /// Reconcile against a set of live PIDs; mark jobs whose process vanished as Failed.
    /// Called at startup by the orphan reaper.
    pub fn reap_orphans(&self, live_pids: &HashSet<u32>) -> Vec<JobId> {
        let mut reaped = Vec::new();
        let mut jobs = self.jobs.lock().unwrap();
        for j in jobs.values_mut() {
            if let Some(pid) = j.pid {
                if !live_pids.contains(&pid) && matches!(j.state, JobState::Running | JobState::Started) {
                    j.state = JobState::Failed;
                    reaped.push(j.id.clone());
                }
            }
        }
        reaped
    }

    /// Cancel every job in a workspace (cancel tree root).
    pub fn cancel_workspace(&self, ws: &WorkspaceId, mode: CancelMode) -> Vec<JobId> {
        let targets: Vec<JobId> = self.jobs.lock().unwrap().values()
            .filter(|j| j.workspace.as_ref() == Some(ws))
            .map(|j| j.id.clone()).collect();
        for id in &targets {
            self.request_cancel(id, mode);
        }
        targets
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cancel_tree_and_reaper() {
        let r = JobRegistry::new();
        let ws = WorkspaceId("ws_1".into());
        let j1 = JobId("j1".into());
        let j2 = JobId("j2".into());
        r.register(j1.clone(), Some(ws.clone()));
        r.register(j2.clone(), Some(ws.clone()));
        r.set_state(&j1, JobState::Running);
        r.attach_process(&j1, 4242, 4242);
        assert_eq!(r.cancel_workspace(&ws, CancelMode::Graceful).len(), 2);
        assert_eq!(r.cancel_requested(&j1), Some(CancelMode::Graceful));
        let live = HashSet::new(); // no live PIDs
        let reaped = r.reap_orphans(&live);
        assert!(reaped.contains(&j1));
    }
}
