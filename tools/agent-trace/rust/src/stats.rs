use std::collections::{BTreeMap, BTreeSet};
use std::path::Path;

use anyhow::Result;
use serde::Serialize;

use crate::model::{Record, Usage};
use crate::parse::{self, TranscriptFile};

#[derive(Debug, Clone, Default, Serialize)]
pub struct TokenTotals {
    pub input_tokens: u64,
    pub output_tokens: u64,
    pub cache_creation_input_tokens: u64,
    pub cache_read_input_tokens: u64,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct ProjectStats {
    pub files: usize,
    pub sessions: usize,
    pub records: u64,
    pub malformed: u64,
    pub api_errors: u64,
    pub tool_result_errors: u64,
    pub tokens: TokenTotals,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct StatsReport {
    pub root: String,
    pub files: usize,
    pub sessions: usize,
    pub records: u64,
    pub malformed: u64,
    pub records_by_type: BTreeMap<String, u64>,
    pub tool_uses: BTreeMap<String, u64>,
    pub models: BTreeMap<String, u64>,
    pub tokens: TokenTotals,
    pub api_errors: u64,
    pub tool_result_errors: u64,
    pub projects: BTreeMap<String, ProjectStats>,
}

#[derive(Default)]
struct StatsBuilder {
    report: StatsReport,
    sessions: BTreeSet<String>,
    project_sessions: BTreeMap<String, BTreeSet<String>>,
}

pub fn collect(root: &Path) -> Result<StatsReport> {
    let transcripts = parse::discover_transcripts(root)?;
    let mut builder = StatsBuilder::new(root, transcripts.len());

    for transcript in transcripts {
        builder.add_file(&transcript);
        let fallback_session = parse::session_fallback(&transcript.path);
        let project = transcript.project.clone();
        let report = parse::parse_jsonl_file(&transcript.path, |parsed| {
            let session_id = parsed
                .record
                .session_id
                .clone()
                .unwrap_or_else(|| fallback_session.clone());
            builder.add_record(&project, &session_id, &parsed.record);
            Ok(())
        })?;
        builder.add_malformed(&project, report.malformed as u64);
    }

    Ok(builder.finish())
}

impl StatsBuilder {
    fn new(root: &Path, file_count: usize) -> Self {
        let mut report = StatsReport {
            root: root.display().to_string(),
            files: file_count,
            ..StatsReport::default()
        };
        for record_type in [
            "assistant",
            "user",
            "attachment",
            "last-prompt",
            "queue-operation",
            "mode",
            "system",
            "pr-link",
            "custom-title",
            "summary",
            "other",
        ] {
            report.records_by_type.insert(record_type.to_string(), 0);
        }

        Self {
            report,
            sessions: BTreeSet::new(),
            project_sessions: BTreeMap::new(),
        }
    }

    fn add_file(&mut self, transcript: &TranscriptFile) {
        self.report
            .projects
            .entry(transcript.project.clone())
            .or_default()
            .files += 1;
    }

    fn add_record(&mut self, project: &str, session_id: &str, record: &Record) {
        self.sessions.insert(session_id.to_string());
        self.project_sessions
            .entry(project.to_string())
            .or_default()
            .insert(session_id.to_string());

        self.report.records += 1;
        *self
            .report
            .records_by_type
            .entry(record.type_bucket().to_string())
            .or_default() += 1;

        let project_stats = self.report.projects.entry(project.to_string()).or_default();
        project_stats.records += 1;

        if record.is_api_error() {
            self.report.api_errors += 1;
            project_stats.api_errors += 1;
        }

        let tool_errors = record.tool_result_error_count() as u64;
        if tool_errors > 0 {
            self.report.tool_result_errors += tool_errors;
            project_stats.tool_result_errors += tool_errors;
        }

        if let Some(message) = record.message.as_ref() {
            if let Some(model) = message.model.as_deref() {
                *self.report.models.entry(model.to_string()).or_default() += 1;
            }
            if let Some(usage) = message.usage.as_ref() {
                add_usage(&mut self.report.tokens, usage);
                add_usage(&mut project_stats.tokens, usage);
            }
        }

        for tool in record.tool_names() {
            *self.report.tool_uses.entry(tool.to_string()).or_default() += 1;
        }
    }

    fn add_malformed(&mut self, project: &str, malformed: u64) {
        self.report.malformed += malformed;
        self.report
            .projects
            .entry(project.to_string())
            .or_default()
            .malformed += malformed;
    }

    fn finish(mut self) -> StatsReport {
        self.report.sessions = self.sessions.len();
        for (project, sessions) in self.project_sessions {
            self.report.projects.entry(project).or_default().sessions = sessions.len();
        }
        self.report
    }
}

fn add_usage(total: &mut TokenTotals, usage: &Usage) {
    total.input_tokens += usage.input_tokens.unwrap_or(0);
    total.output_tokens += usage.output_tokens.unwrap_or(0);
    total.cache_creation_input_tokens += usage.cache_creation_input_tokens.unwrap_or(0);
    total.cache_read_input_tokens += usage.cache_read_input_tokens.unwrap_or(0);
}

pub fn render_table(report: &StatsReport) -> String {
    let mut out = String::new();
    out.push_str("Agent Trace Stats\n");
    out.push_str(&format!("root: {}\n", report.root));
    out.push_str(&format!("files: {}\n", report.files));
    out.push_str(&format!("sessions: {}\n", report.sessions));
    out.push_str(&format!("records: {}\n", report.records));
    out.push_str(&format!("malformed: {}\n", report.malformed));
    out.push_str(&format!("api_errors: {}\n", report.api_errors));
    out.push_str(&format!(
        "tool_result_errors: {}\n\n",
        report.tool_result_errors
    ));

    push_map_section(
        &mut out,
        "Records by type",
        "type",
        "count",
        &report.records_by_type,
    );
    push_map_section(&mut out, "Models", "model", "count", &report.models);
    push_map_section(
        &mut out,
        "Tool use histogram",
        "tool",
        "count",
        &report.tool_uses,
    );

    out.push_str("Token totals\n");
    out.push_str(&format!(
        "  {:<30} {:>15}\n",
        "input_tokens", report.tokens.input_tokens
    ));
    out.push_str(&format!(
        "  {:<30} {:>15}\n",
        "output_tokens", report.tokens.output_tokens
    ));
    out.push_str(&format!(
        "  {:<30} {:>15}\n",
        "cache_creation_input_tokens", report.tokens.cache_creation_input_tokens
    ));
    out.push_str(&format!(
        "  {:<30} {:>15}\n\n",
        "cache_read_input_tokens", report.tokens.cache_read_input_tokens
    ));

    out.push_str("Projects\n");
    out.push_str(&format!(
        "  {:<55} {:>7} {:>8} {:>10} {:>10} {:>10} {:>10} {:>14} {:>14}\n",
        "project",
        "files",
        "sessions",
        "records",
        "malformed",
        "api_err",
        "tool_err",
        "input_tok",
        "output_tok"
    ));
    for (project, stats) in &report.projects {
        out.push_str(&format!(
            "  {:<55} {:>7} {:>8} {:>10} {:>10} {:>10} {:>10} {:>14} {:>14}\n",
            truncate_middle(project, 55),
            stats.files,
            stats.sessions,
            stats.records,
            stats.malformed,
            stats.api_errors,
            stats.tool_result_errors,
            stats.tokens.input_tokens,
            stats.tokens.output_tokens
        ));
    }

    out
}

fn push_map_section(
    out: &mut String,
    title: &str,
    key_header: &str,
    value_header: &str,
    map: &BTreeMap<String, u64>,
) {
    out.push_str(title);
    out.push('\n');
    out.push_str(&format!("  {:<32} {:>15}\n", key_header, value_header));
    for (key, value) in map {
        if *value == 0 && title != "Records by type" {
            continue;
        }
        out.push_str(&format!(
            "  {:<32} {:>15}\n",
            truncate_middle(key, 32),
            value
        ));
    }
    out.push('\n');
}

fn truncate_middle(value: &str, width: usize) -> String {
    let len = value.chars().count();
    if len <= width {
        return value.to_string();
    }
    if width <= 1 {
        return "…".to_string();
    }

    let left = (width - 1) / 2;
    let right = width - 1 - left;
    let prefix: String = value.chars().take(left).collect();
    let suffix: String = value
        .chars()
        .rev()
        .take(right)
        .collect::<Vec<_>>()
        .into_iter()
        .rev()
        .collect();
    format!("{prefix}…{suffix}")
}
