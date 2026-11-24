// execution_scope.rs — Per-run scope, session and campaign binding (1-5-5.md §6.1).
// Scope is OPT-IN advisory metadata that filters the plan, never a hard wall (D7/I7).

use super::capability_model::*;
use std::collections::BTreeMap;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ExecutionScope {
    pub workspace: Option<WorkspaceId>,
    pub campaign: Option<String>,
    pub session: Option<String>,
    /// Advisory target list. Does not gate execution — only annotates.
    pub targets: Vec<String>,
    /// Advisory exclusions. Warnings only (D6), never a block.
    pub exclusions: Vec<String>,
    pub annotations: BTreeMap<String, String>,
}

impl Default for ExecutionScope {
    fn default() -> Self {
        Self {
            workspace: None,
            campaign: None,
            session: None,
            targets: Vec::new(),
            exclusions: Vec::new(),
            annotations: BTreeMap::new(),
        }
    }
}

impl ExecutionScope {
    pub fn from_json(s: &str) -> Self {
        serde_json::from_str(s).unwrap_or_default()
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string())
    }

    /// Returns advisory warnings for targets that fall inside exclusions.
    /// These are annotations surfaced in the UI, never blockers (D6).
    pub fn warnings(&self) -> Vec<String> {
        let mut out = Vec::new();
        for t in &self.targets {
            for x in &self.exclusions {
                if t == x || (!x.is_empty() && t.contains(x)) {
                    out.push(format!("target '{}' matches advisory exclusion '{}'", t, x));
                }
            }
        }
        out
    }

    /// True if this scope annotates any in-scope target.
    pub fn is_scoped(&self) -> bool {
        !self.targets.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn scope_is_advisory_not_blocking() {
        let s = ExecutionScope {
            exclusions: vec!["example.com".into()],
            targets: vec!["foo.example.com".into()],
            ..Default::default()
        };
        assert_eq!(s.warnings().len(), 1);
        assert!(s.is_scoped()); // execution is never blocked
    }

    #[test]
    fn scope_roundtrips() {
        let s = ExecutionScope { campaign: Some("op1".into()), ..Default::default() };
        let s2 = ExecutionScope::from_json(&s.to_json());
        assert_eq!(s2.campaign.as_deref(), Some("op1"));
    }
}
