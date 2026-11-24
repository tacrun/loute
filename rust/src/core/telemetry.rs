// telemetry.rs - Event bus to Flutter per 1-5-5.md §6.15.
// JobEvent stream: queued · planned · started · stdout(line) · stderr(line) ·
// progress(pct, phase) · parsed(counts) · artifact(id) · finding(id) ·
// provider_state · heartbeat · completed(status) · cancelled(mode) · failed(error).

use std::sync::Arc;
use std::sync::Mutex;
use tokio::sync::broadcast;

use super::capability_model::*;

pub struct TelemetryBus {
    sender: broadcast::Sender<JobEvent>,
    recent: Arc<Mutex<Vec<JobEvent>>>,
}

impl TelemetryBus {
    pub fn new(buffer: usize) -> Self {
        let (sender, _) = broadcast::channel(buffer);
        Self {
            sender,
            recent: Arc::new(Mutex::new(Vec::new())),
        }
    }

    pub fn subscribe(&self) -> broadcast::Receiver<JobEvent> {
        self.sender.subscribe()
    }

    pub fn emit(&self, event: JobEvent) {
        let _ = self.sender.send(event.clone());
        let mut recent = self.recent.lock().unwrap();
        recent.push(event);
        // Keep last 1000 events
        if recent.len() > 1000 {
            recent.drain(0..100);
        }
    }

    pub fn recent_events(&self) -> Vec<JobEvent> {
        self.recent.lock().unwrap().clone()
    }
}
