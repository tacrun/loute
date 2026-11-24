// graph.rs - Asset/evidence graph, pivots per 1-5-5.md §6.10, §9.5.
// Nodes = assets. Edges = resolves_to · hosts · exposes · authenticates_to · trusts ·
// pivots_to · escalates_via · persists_via · derived_from.

use std::collections::HashMap;
use std::sync::Mutex;

use super::capability_model::*;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct GraphEdge {
    pub from: AssetId,
    pub to: AssetId,
    pub kind: EdgeKind,
    pub source_job: Option<JobId>,
}

pub struct AssetGraph {
    nodes: Mutex<Vec<Asset>>,
    edges: Mutex<Vec<GraphEdge>>,
}

impl AssetGraph {
    pub fn new() -> Self {
        Self {
            nodes: Mutex::new(Vec::new()),
            edges: Mutex::new(Vec::new()),
        }
    }

    pub fn upsert_asset(&self, asset: Asset) {
        let mut nodes = self.nodes.lock().unwrap();
        if let Some(existing) = nodes.iter_mut().find(|a| a.id == asset.id) {
            *existing = asset;
        } else {
            nodes.push(asset);
        }
    }

    pub fn add_edge(&self, edge: GraphEdge) {
        let mut edges = self.edges.lock().unwrap();
        if !edges.iter().any(|e|
            e.from == edge.from && e.to == edge.to && e.kind == edge.kind
        ) {
            edges.push(edge);
        }
    }

    pub fn nodes(&self) -> Vec<Asset> {
        self.nodes.lock().unwrap().clone()
    }

    pub fn edges(&self) -> Vec<GraphEdge> {
        self.edges.lock().unwrap().clone()
    }

    /// Query the graph with optional depth and kind filter.
    pub fn query(&self, start: &AssetId, depth: usize, kind_filter: Option<&[EdgeKind]>) -> GraphSlice {
        let edges = self.edges.lock().unwrap();
        let nodes = self.nodes.lock().unwrap();

        let mut visited = std::collections::HashSet::new();
        let mut result_nodes = Vec::new();
        let mut result_edges = Vec::new();
        let mut frontier = vec![(start.clone(), 0usize)];

        while let Some((current, d)) = frontier.pop() {
            if d > depth || visited.contains(&current) {
                continue;
            }
            visited.insert(current.clone());

            if let Some(node) = nodes.iter().find(|n| n.id == current) {
                result_nodes.push(node.clone());
            }

            for edge in edges.iter() {
                if edge.from == current {
                    if kind_filter.is_none_or(|filter| filter.contains(&edge.kind)) {
                        result_edges.push(edge.clone());
                        frontier.push((edge.to.clone(), d + 1));
                    }
                }
            }
        }

        GraphSlice {
            nodes: result_nodes,
            edges: result_edges,
        }
    }
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct GraphSlice {
    pub nodes: Vec<Asset>,
    pub edges: Vec<GraphEdge>,
}
