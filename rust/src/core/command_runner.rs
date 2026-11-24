// command_runner.rs - argv-only execution per 1-5-5.md §6.4.
// Uses std::process::Command with arg() per element - never a joined string.
// No shell. Ever.

use std::process::Stdio;
use std::time::Duration;
use tokio::process::Command;

use super::capability_model::*;

pub struct CommandRunner;

impl CommandRunner {
    /// Execute an ExecutionPlan - runs the binary with argv, captures stdout/stderr,
    /// enforces timeout, classifies exit code.
    pub async fn run(plan: &ExecutionPlan) -> ExecutionResult {
        let start = std::time::Instant::now();

        // Native capabilities are handled by the phase executor, not here
        if plan.binary_path.to_str() == Some("(native)") {
            return ExecutionResult {
                job_id: plan.job_id.clone(),
                capability: plan.capability.clone(),
                exit_code: 0,
                status: "native-pending".into(),
                stdout: String::new(),
                stderr: String::new(),
                duration_secs: start.elapsed().as_secs_f64(),
                artifacts: vec![],
                findings: vec![],
                assets: vec![],
                simulated: true,
                command_preview: plan.command_preview.clone(),
                provider_version: "native".into(),
                catalog_hash: String::new(),
            };
        }

        // Build the command - explicit argv, no shell
        let mut cmd = Command::new(&plan.binary_path);
        cmd.args(&plan.argv);
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());
        cmd.kill_on_drop(true);

        // Set env
        for (key, val) in &plan.env {
            cmd.env(key, val);
        }

        // Spawn
        let child = match cmd.spawn() {
            Ok(c) => c,
            Err(e) => {
                return ExecutionResult {
                    job_id: plan.job_id.clone(),
                    capability: plan.capability.clone(),
                    exit_code: 127,
                    status: classify_exit_code(127),
                    stdout: String::new(),
                    stderr: format!("Failed to spawn: {}", e),
                    duration_secs: start.elapsed().as_secs_f64(),
                    artifacts: vec![],
                    findings: vec![],
                    assets: vec![],
                    simulated: false,
                    command_preview: plan.command_preview.clone(),
                    provider_version: String::new(),
                    catalog_hash: String::new(),
                };
            }
        };

        // Wait with timeout
        let timeout = plan.timeout;
        let result = tokio::time::timeout(timeout, child.wait_with_output()).await;

        match result {
            Ok(Ok(output)) => {
                let exit_code = output.status.code().unwrap_or(-1);
                let stdout = String::from_utf8_lossy(&output.stdout).to_string();
                let stderr = String::from_utf8_lossy(&output.stderr).to_string();

                // Cap stdout/stderr
                let stdout_capped = if stdout.len() > 64 * 1024 * 1024 {
                    stdout[..64 * 1024 * 1024].to_string()
                } else {
                    stdout
                };
                let stderr_capped = if stderr.len() > 8 * 1024 * 1024 {
                    stderr[..8 * 1024 * 1024].to_string()
                } else {
                    stderr
                };

                ExecutionResult {
                    job_id: plan.job_id.clone(),
                    capability: plan.capability.clone(),
                    exit_code,
                    status: classify_exit_code(exit_code),
                    stdout: stdout_capped,
                    stderr: stderr_capped,
                    duration_secs: start.elapsed().as_secs_f64(),
                    artifacts: vec![],
                    findings: vec![],
                    assets: vec![],
                    simulated: false,
                    command_preview: plan.command_preview.clone(),
                    provider_version: String::new(),
                    catalog_hash: String::new(),
                }
            }
            Ok(Err(e)) => ExecutionResult {
                job_id: plan.job_id.clone(),
                capability: plan.capability.clone(),
                exit_code: -1,
                status: "provider-error".into(),
                stdout: String::new(),
                stderr: format!("Process error: {}", e),
                duration_secs: start.elapsed().as_secs_f64(),
                artifacts: vec![],
                findings: vec![],
                assets: vec![],
                simulated: false,
                command_preview: plan.command_preview.clone(),
                provider_version: String::new(),
                catalog_hash: String::new(),
            },
            Err(_) => ExecutionResult {
                job_id: plan.job_id.clone(),
                capability: plan.capability.clone(),
                exit_code: 124,
                status: "timeout".into(),
                stdout: String::new(),
                stderr: "Process timed out".into(),
                duration_secs: start.elapsed().as_secs_f64(),
                artifacts: vec![],
                findings: vec![],
                assets: vec![],
                simulated: false,
                command_preview: plan.command_preview.clone(),
                provider_version: String::new(),
                catalog_hash: String::new(),
            },
        }
    }
}

/// Exit code classification per §6.4.
fn classify_exit_code(code: i32) -> String {
    match code {
        0 => "ok".into(),
        1 => "findings-present".into(),
        2 => "usage".into(),
        124 => "timeout".into(),
        126 => "not-executable".into(),
        127 => "not-found".into(),
        130 => "cancelled".into(),
        _ => "provider-error".into(),
    }
}
