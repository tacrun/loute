// runtime.rs — Full execution lifecycle orchestrator (1-5-5.md §12.1).
// validate → plan → enqueue → dispatch → stream → parse → normalize → persist → complete.
// Every capability runs through this path; no silent stub fallback (F2/I8).

use std::collections::BTreeMap;
use std::sync::Mutex;

use super::capability_model::*;
use crate::parsers::ParseOutcome;
use super::command_runner::CommandRunner;
use super::dispatcher::Dispatcher;
use super::finding_normalizer::FindingNormalizer;

/// Result of a full capability run including normalized data.
#[derive(Debug, Clone, serde::Serialize)]
pub struct RuntimeResult {
    pub result: ExecutionResult,
    pub assets: Vec<Asset>,
    pub findings: Vec<Finding>,
    pub parse_stats: ParseStats,
}

#[derive(Debug, Clone, Default, serde::Serialize)]
pub struct ParseStats {
    pub assets: usize,
    pub findings: usize,
    pub unparsed: usize,
}

pub struct Runtime {
    dispatcher: Dispatcher,
    normalizer: FindingNormalizer,
    history: Mutex<Vec<RuntimeResult>>,
}

impl Default for Runtime {
    fn default() -> Self { Self::new() }
}

impl Runtime {
    pub fn new() -> Self {
        Self {
            dispatcher: Dispatcher::new(),
            normalizer: FindingNormalizer::new(),
            history: Mutex::new(Vec::new()),
        }
    }

    /// Plan a capability (dry-run) without executing.
    pub fn plan(&self, id: &str, inputs: &BTreeMap<String, String>, scope: Option<&str>) -> Result<ExecutionPlan, PlanError> {
        self.dispatcher.plan(&CapabilityId(id.to_string()), inputs, scope)
    }

    /// Execute a capability end-to-end: plan → run → parse → normalize → persist.
    pub async fn run(
        &self,
        id: &str,
        inputs: &BTreeMap<String, String>,
        scope: Option<&str>,
    ) -> Result<RuntimeResult, PlanError> {
        // 1. Plan
        let plan = self.plan(id, inputs, scope)?;

        // 2. Execute (argv-only via command runner)
        let mut result = CommandRunner::run(&plan).await;

        // Stamp provenance (I8)
        result.catalog_hash = crate::CATALOG_HASH.to_string();

        // 3. Parse stdout into typed values
        let parsed: ParseOutcome = crate::parsers::parse(&plan.parser, &result.stdout);

        // 4. Normalize into finding/asset model (evidence-first, dedupe, scoring)
        let workspace = WorkspaceId("default".into());
        self.normalizer.ingest(&plan.job_id, &workspace, &plan.capability, &parsed);
        let assets = self.normalizer.list_assets();
        let findings = self.normalizer.list_findings();

        // 5. Reflect counts into the execution result
        result.assets = assets.iter().map(|a| a.key.clone()).collect();
        result.findings = findings.iter().map(|f| f.title.clone()).collect();
        result.simulated = false;

        let stats = ParseStats {
            assets: parsed.assets.len(),
            findings: parsed.findings.len(),
            unparsed: parsed.unparsed_count as usize,
        };

        let rr = RuntimeResult { result, assets, findings, parse_stats: stats };
        self.history.lock().unwrap().push(rr.clone());
        Ok(rr)
    }

    pub fn history(&self) -> Vec<RuntimeResult> {
        self.history.lock().unwrap().clone()
    }
}
