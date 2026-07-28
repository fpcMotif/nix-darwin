use std::collections::BTreeMap;
use std::path::Path;

use anyhow::Result;
use chrono::DateTime;
use serde::Serialize;

use crate::parse;

#[derive(Debug, Clone, Serialize)]
pub struct PromptHit {
    pub timestamp: String,
    pub project: String,
    pub session_id: String,
    pub source: String,
    pub prompt: String,
}

#[derive(Debug, Default)]
struct PromptCandidate {
    queue: Option<PromptHit>,
    user: Option<PromptHit>,
}

pub fn collect(root: &Path, grep: Option<&str>, min_len: usize) -> Result<Vec<PromptHit>> {
    let transcripts = parse::discover_transcripts(root)?;
    let mut candidates: BTreeMap<(String, String), PromptCandidate> = BTreeMap::new();

    for transcript in transcripts {
        let fallback_session = parse::session_fallback(&transcript.path);
        let project = transcript.project.clone();
        parse::parse_jsonl_file(&transcript.path, |parsed| {
            let session_id = parsed
                .record
                .session_id
                .clone()
                .unwrap_or_else(|| fallback_session.clone());
            let candidate = candidates
                .entry((project.clone(), session_id.clone()))
                .or_default();

            if candidate.queue.is_none() {
                if let Some(prompt) = parsed.record.queue_prompt() {
                    candidate.queue = Some(PromptHit {
                        timestamp: parsed.record.timestamp.clone().unwrap_or_default(),
                        project: project.clone(),
                        session_id: session_id.clone(),
                        source: "queue".to_string(),
                        prompt,
                    });
                }
            }

            if candidate.user.is_none() {
                if let Some(prompt) = parsed.record.human_prompt() {
                    candidate.user = Some(PromptHit {
                        timestamp: parsed.record.timestamp.clone().unwrap_or_default(),
                        project: project.clone(),
                        session_id,
                        source: "user".to_string(),
                        prompt: prompt.to_string(),
                    });
                }
            }

            Ok(())
        })?;
    }

    let mut hits = candidates
        .into_values()
        .filter_map(|candidate| candidate.queue.or(candidate.user))
        .filter(|hit| matches_filters(&hit.prompt, grep, min_len))
        .collect::<Vec<_>>();

    hits.sort_by(|left, right| {
        timestamp_key(&left.timestamp)
            .cmp(&timestamp_key(&right.timestamp))
            .then_with(|| left.project.cmp(&right.project))
            .then_with(|| left.session_id.cmp(&right.session_id))
    });

    Ok(hits)
}

pub fn render_table(hits: &[PromptHit]) -> String {
    let mut out = String::new();
    out.push_str(&format!(
        "{:<30} {:<42} {:<36} {:<6} {}\n",
        "timestamp", "project", "sessionId", "source", "prompt"
    ));

    for hit in hits {
        out.push_str(&format!(
            "{:<30} {:<42} {:<36} {:<6} {}\n",
            truncate_end(&hit.timestamp, 30),
            truncate_end(&hit.project, 42),
            truncate_end(&hit.session_id, 36),
            hit.source,
            truncate_end(&one_line(&hit.prompt), 240)
        ));
    }

    out
}

fn matches_filters(prompt: &str, grep: Option<&str>, min_len: usize) -> bool {
    if prompt.chars().count() < min_len {
        return false;
    }

    if let Some(pattern) = grep {
        return prompt.to_lowercase().contains(&pattern.to_lowercase());
    }

    true
}

fn timestamp_key(timestamp: &str) -> (i64, &str) {
    let millis = DateTime::parse_from_rfc3339(timestamp)
        .map(|timestamp| timestamp.timestamp_millis())
        .unwrap_or(i64::MAX);
    (millis, timestamp)
}

fn one_line(value: &str) -> String {
    value.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn truncate_end(value: &str, width: usize) -> String {
    if value.chars().count() <= width {
        return value.to_string();
    }
    if width <= 1 {
        return "…".to_string();
    }

    let mut out = value.chars().take(width - 1).collect::<String>();
    out.push('…');
    out
}
