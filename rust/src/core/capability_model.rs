// capability_model.rs — Typed structs and enums for the LOUTE capability schema.
// Schema v1 (compatible) + v2 extensions per 1-5-5.md §7.

use std::collections::BTreeMap;
use std::path::PathBuf;
use std::time::Duration;

// ── Newtype wrappers ──

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct CapabilityId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct ProviderId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct JobId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct WorkspaceId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct AssetId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct FindingId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct ArtifactId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct ParserId(pub String);

impl std::fmt::Display for CapabilityId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::fmt::Display for JobId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

// ── Enums ──

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Phase {
    Recon,
    Surface,
    Vulnerability,
    Payload,
    Escalation,
    Credentials,
    Lateral,
    Persistence,
    Exploitation,
    Wireless,
    Ctf,
}

impl Phase {
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "recon" | "reconnaissance" => Some(Self::Recon),
            "surface" | "attack_surface" | "attack surface" => Some(Self::Surface),
            "vulnerability" => Some(Self::Vulnerability),
            "payload" => Some(Self::Payload),
            "escalation" => Some(Self::Escalation),
            "credentials" => Some(Self::Credentials),
            "lateral" => Some(Self::Lateral),
            "persistence" => Some(Self::Persistence),
            "exploitation" => Some(Self::Exploitation),
            "wireless" => Some(Self::Wireless),
            "ctf" | "ctf_challenges" | "ctf challenges" => Some(Self::Ctf),
            _ => None,
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Recon => "recon",
            Self::Surface => "surface",
            Self::Vulnerability => "vulnerability",
            Self::Payload => "payload",
            Self::Escalation => "escalation",
            Self::Credentials => "credentials",
            Self::Lateral => "lateral",
            Self::Persistence => "persistence",
            Self::Exploitation => "exploitation",
            Self::Wireless => "wireless",
            Self::Ctf => "ctf",
        }
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            Self::Recon => "RECONNAISSANCE",
            Self::Surface => "ATTACK SURFACE",
            Self::Vulnerability => "VULNERABILITY",
            Self::Payload => "PAYLOAD",
            Self::Escalation => "ESCALATION",
            Self::Credentials => "CREDENTIALS",
            Self::Lateral => "LATERAL",
            Self::Persistence => "PERSISTENCE",
            Self::Exploitation => "EXPLOITATION",
            Self::Wireless => "WIRELESS",
            Self::Ctf => "CTF CHALLENGES",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum RiskTier {
    R0,
    R1,
    R2,
    R3,
    R4,
}

impl RiskTier {
    pub fn from_str(s: &str) -> Self {
        match s.to_uppercase().as_str() {
            "R0" => Self::R0,
            "R1" => Self::R1,
            "R2" => Self::R2,
            "R3" => Self::R3,
            "R4" => Self::R4,
            _ => Self::R1,
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            Self::R0 => "passive",
            Self::R1 => "light active",
            Self::R2 => "active intrusive",
            Self::R3 => "credential/exploit",
            Self::R4 => "destructive",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum NoiseLevel {
    Silent,
    Low,
    Medium,
    High,
    Screaming,
}

impl NoiseLevel {
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "silent" => Some(Self::Silent),
            "low" => Some(Self::Low),
            "medium" => Some(Self::Medium),
            "high" => Some(Self::High),
            "screaming" => Some(Self::Screaming),
            _ => None,
        }
    }

    pub fn level(&self) -> u8 {
        match self {
            Self::Silent => 0,
            Self::Low => 1,
            Self::Medium => 2,
            Self::High => 3,
            Self::Screaming => 4,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct MitreId(pub String);

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Platform {
    Linux,
    Android,
    Windows,
    Macos,
}

impl Platform {
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "linux" => Some(Self::Linux),
            "android" => Some(Self::Android),
            "windows" => Some(Self::Windows),
            "macos" | "mac" => Some(Self::Macos),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PrivilegeReq {
    None,
    User,
    Root,
    Admin,
    System,
}

impl PrivilegeReq {
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "none" => Some(Self::None),
            "user" => Some(Self::User),
            "root" | "sudo" => Some(Self::Root),
            "admin" | "administrator" => Some(Self::Admin),
            "system" => Some(Self::System),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum NetworkRequirement {
    Required,
    Optional,
    None,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AssetKind {
    Domain,
    Subdomain,
    Ip,
    Cidr,
    Port,
    Service,
    Url,
    Endpoint,
    Parameter,
    CloudAccount,
    Bucket,
    Container,
    Image,
    K8sObject,
    AdDomain,
    AdUser,
    AdGroup,
    AdComputer,
    Ou,
    Gpo,
    Host,
    CredentialRef,
    Session,
    Payload,
    Certificate,
    Repo,
    Pipeline,
    Ap,
    Client,
    BleDevice,
    Flag,
    File,
}

impl AssetKind {
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "domain" => Some(Self::Domain),
            "subdomain" => Some(Self::Subdomain),
            "ip" => Some(Self::Ip),
            "cidr" => Some(Self::Cidr),
            "port" => Some(Self::Port),
            "service" => Some(Self::Service),
            "url" => Some(Self::Url),
            "endpoint" => Some(Self::Endpoint),
            "parameter" => Some(Self::Parameter),
            "cloud_account" => Some(Self::CloudAccount),
            "bucket" => Some(Self::Bucket),
            "container" => Some(Self::Container),
            "image" => Some(Self::Image),
            "k8s_object" => Some(Self::K8sObject),
            "ad_domain" => Some(Self::AdDomain),
            "ad_user" => Some(Self::AdUser),
            "ad_group" => Some(Self::AdGroup),
            "ad_computer" => Some(Self::AdComputer),
            "ou" => Some(Self::Ou),
            "gpo" => Some(Self::Gpo),
            "host" => Some(Self::Host),
            "credential_ref" => Some(Self::CredentialRef),
            "session" => Some(Self::Session),
            "payload" => Some(Self::Payload),
            "certificate" => Some(Self::Certificate),
            "repo" => Some(Self::Repo),
            "pipeline" => Some(Self::Pipeline),
            "ap" => Some(Self::Ap),
            "client" => Some(Self::Client),
            "ble_device" => Some(Self::BleDevice),
            "flag" => Some(Self::Flag),
            "file" => Some(Self::File),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum OutputMode {
    Lines,
    Json,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct InputSpec {
    pub name: String,
    pub kind: InputKind,
    pub required: bool,
    pub default: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum InputKind {
    Domain,
    Ip,
    Cidr,
    Url,
    File,
    Apk,
    Hash,
    Cred,
    Kubeconfig,
    Interface,
    Text,
    Number,
    Boolean,
}

impl InputKind {
    pub fn from_str(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "domain" => Self::Domain,
            "ip" => Self::Ip,
            "cidr" => Self::Cidr,
            "url" => Self::Url,
            "file" | "filepath" => Self::File,
            "apk" | "ipa" => Self::Apk,
            "hash" => Self::Hash,
            "cred" | "credentials" => Self::Cred,
            "kubeconfig" => Self::Kubeconfig,
            "interface" => Self::Interface,
            "number" | "int" | "integer" => Self::Number,
            "bool" | "boolean" => Self::Boolean,
            _ => Self::Text,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum ArtifactKind {
    Text,
    Json,
    Html,
    Pcap,
    Binary,
    Image,
    Report,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AvailabilityState {
    Available,
    Missing,
    VersionMismatch,
    PermissionDenied,
    InterfaceMissing,
    Degraded,
    Probing,
}

impl AvailabilityState {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Available => "available",
            Self::Missing => "missing",
            Self::VersionMismatch => "version-mismatch",
            Self::PermissionDenied => "permission-denied",
            Self::InterfaceMissing => "interface-missing",
            Self::Degraded => "degraded",
            Self::Probing => "probing",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum JobState {
    Queued,
    Planned,
    Started,
    Running,
    Parsing,
    Completed,
    Cancelled,
    Failed,
    Timeout,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Severity {
    Info,
    Low,
    Medium,
    High,
    Critical,
}

impl Severity {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Info => "info",
            Self::Low => "low",
            Self::Medium => "medium",
            Self::High => "high",
            Self::Critical => "critical",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Confidence {
    Unverified,
    Low,
    Medium,
    High,
    Certain,
}

impl Confidence {
    pub fn from_score(score: f32) -> Self {
        if score < 0.3 {
            Self::Unverified
        } else if score < 0.5 {
            Self::Low
        } else if score < 0.7 {
            Self::Medium
        } else if score < 0.9 {
            Self::High
        } else {
            Self::Certain
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FindingState {
    New,
    Triaged,
    Confirmed,
    FalsePositive,
    Remediated,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CancelMode {
    Graceful,
    Force,
}

// ── Line schema ──

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct LineSchema {
    pub kind: String,
    pub fields: Vec<String>,
}

// ── Capability struct (full schema v2 model) ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct Capability {
    pub schema: u8,
    pub id: CapabilityId,
    pub phase: Phase,
    pub label: String,
    pub summary: String,
    pub risk: RiskTier,
    pub noise: NoiseLevel,
    pub mitre: Vec<MitreId>,
    pub platforms: Vec<Platform>,
    pub privileges: Vec<PrivilegeReq>,
    pub network: bool,
    pub requires: Vec<CapabilityId>,
    pub provides: Vec<String>,
    pub inputs: Vec<InputSpec>,
    pub provider: ProviderId,
    pub binary: String,
    pub operation: String,
    pub args: Vec<String>,
    pub output: OutputMode,
    pub line_schema: Option<LineSchema>,
    pub parser: String,
    pub probe: Vec<String>,
    pub timeout: u64,
    pub retry: u8,
    pub concurrency: u8,
    pub cache_ttl: u64,
    pub artifacts: Vec<String>,
    pub reversible: bool,
    pub cleanup: Option<CapabilityId>,
    pub chains: Vec<CapabilityId>,
    pub opsec_safe: bool,
    pub native: bool,
    /// True when a capability declares its own pre-escaped single-string args
    /// (payload/regex data). Execution is still argv-only — never a shell (I1).
    pub shell_escape: bool,
}

impl Capability {
    pub fn timeout_duration(&self) -> Duration {
        Duration::from_secs(self.timeout)
    }
}

// ── Execution plan ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ExecutionPlan {
    pub job_id: JobId,
    pub capability: CapabilityId,
    pub provider: ProviderId,
    pub binary_path: PathBuf,
    pub argv: Vec<String>,
    pub env: BTreeMap<String, String>,
    pub cwd: PathBuf,
    pub timeout: Duration,
    pub retries: u8,
    pub parser: String,
    pub opsec: String,
    pub artifact_targets: Vec<String>,
    pub command_preview: String,
}

// ── Plan errors ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub enum PlanError {
    CapabilityNotFound(String),
    InputValidation(String),
    PlaceholderUnresolved(String),
    WordlistMissing(String),
    ProviderUnavailable(String),
    PlatformUnsupported(String),
    PrivilegeInsufficient(String),
    ArgvMaterialization(String),
    Internal(String),
}

impl std::fmt::Display for PlanError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::CapabilityNotFound(id) => write!(f, "capability not found: {id}"),
            Self::InputValidation(msg) => write!(f, "input validation: {msg}"),
            Self::PlaceholderUnresolved(msg) => write!(f, "placeholder unresolved: {msg}"),
            Self::WordlistMissing(msg) => write!(f, "wordlist missing: {msg}"),
            Self::ProviderUnavailable(msg) => write!(f, "provider unavailable: {msg}"),
            Self::PlatformUnsupported(msg) => write!(f, "platform unsupported: {msg}"),
            Self::PrivilegeInsufficient(msg) => write!(f, "privilege insufficient: {msg}"),
            Self::ArgvMaterialization(msg) => write!(f, "argv materialization: {msg}"),
            Self::Internal(msg) => write!(f, "internal: {msg}"),
        }
    }
}

impl std::error::Error for PlanError {}

// ── Job event ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub enum JobEvent {
    Queued,
    Planned,
    Started,
    Stdout(String),
    Stderr(String),
    Progress { pct: f32, phase: String },
    Parsed { assets: u32, findings: u32 },
    Artifact(String),
    Finding(String),
    ProviderState(String),
    Heartbeat,
    Completed { exit_code: i32, status: String },
    Cancelled { mode: String },
    Failed { error: String },
}

// ── Execution result ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ExecutionResult {
    pub job_id: JobId,
    pub capability: CapabilityId,
    pub exit_code: i32,
    pub status: String,
    pub stdout: String,
    pub stderr: String,
    pub duration_secs: f64,
    pub artifacts: Vec<String>,
    pub findings: Vec<String>,
    pub assets: Vec<String>,
    pub simulated: bool,
    pub command_preview: String,
    pub provider_version: String,
    pub catalog_hash: String,
}

// ── Data model: Asset, Finding, Evidence, Artifact ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct Asset {
    pub id: AssetId,
    pub workspace: WorkspaceId,
    pub kind: String,
    pub key: String,
    pub attrs: BTreeMap<String, serde_json::Value>,
    pub first_seen: u64,
    pub last_seen: u64,
    pub sources: Vec<JobId>,
    pub confidence: f32,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct Finding {
    pub id: FindingId,
    pub workspace: WorkspaceId,
    pub asset: AssetId,
    pub capability: CapabilityId,
    pub title: String,
    pub detail: String,
    pub severity: Severity,
    pub confidence: f32,
    pub cvss: Option<f32>,
    pub mitre: Vec<MitreId>,
    pub state: FindingState,
    pub evidence_refs: Vec<ArtifactId>,
    pub observations: u32,
    pub first_seen: u64,
    pub dedupe_key: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct Artifact {
    pub id: ArtifactId,
    pub sha256: String,
    pub media_type: String,
    pub bytes: u64,
    pub path: PathBuf,
    pub job: JobId,
    pub created_at: u64,
}

// ── Graph edge kinds ──

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EdgeKind {
    ResolvesTo,
    Hosts,
    Exposes,
    AuthenticatesTo,
    Trusts,
    PivotsTo,
    EscalatesVia,
    PersistsVia,
    DerivedFrom,
}

// ── Provider summary ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ProviderSummary {
    pub name: String,
    pub binary: String,
    pub state: AvailabilityState,
    pub version: Option<String>,
    pub capability_count: u32,
    pub install_hint: Option<String>,
}

// ── Capability summary (for listing) ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CapabilitySummary {
    pub id: CapabilityId,
    pub phase: Phase,
    pub label: String,
    pub summary: String,
    pub risk: RiskTier,
    pub noise: NoiseLevel,
    pub provider: ProviderId,
    pub native: bool,
    pub opsec_safe: bool,
    pub availability: AvailabilityState,
}

// ── Capability detail (full info) ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CapabilityDetail {
    pub id: CapabilityId,
    pub phase: Phase,
    pub label: String,
    pub summary: String,
    pub risk: RiskTier,
    pub noise: NoiseLevel,
    pub mitre: Vec<MitreId>,
    pub platforms: Vec<Platform>,
    pub privileges: Vec<PrivilegeReq>,
    pub network: bool,
    pub requires: Vec<CapabilityId>,
    pub provides: Vec<String>,
    pub inputs: Vec<InputSpec>,
    pub provider: ProviderId,
    pub binary: String,
    pub operation: String,
    pub args: Vec<String>,
    pub output: OutputMode,
    pub parser: String,
    pub timeout: u64,
    pub concurrency: u8,
    pub native: bool,
    pub opsec_safe: bool,
    pub reversible: bool,
    pub chains: Vec<CapabilityId>,
    pub availability: AvailabilityState,
}

// ── Workspace ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct Workspace {
    pub id: WorkspaceId,
    pub name: String,
    pub kind: WorkspaceKind,
    pub created_at: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum WorkspaceKind {
    Engagement,
    Lab,
    Ctf,
    Research,
}

// ── Audit record ──

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AuditRecord {
    pub timestamp: u64,
    pub actor: String,
    pub workspace: Option<WorkspaceId>,
    pub job: Option<JobId>,
    pub capability: Option<CapabilityId>,
    pub argv: Vec<String>,
    pub provider_version: String,
    pub catalog_hash: String,
    pub exit_code: Option<i32>,
    pub artifact_hashes: Vec<String>,
    pub finding_ids: Vec<String>,
    pub prev_hash: String,
    pub record_hash: String,
}

// ── Validation report ──
// ValidationReport / ValidationError / ValidationWarning live in catalog_validate.rs
// (the authoritative validation module) and are re-exported via core/mod.rs.
