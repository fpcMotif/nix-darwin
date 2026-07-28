use std::collections::{HashMap, HashSet};
use std::path::Path;

use anyhow::Result;

use crate::model::{value_to_text, Record};
use crate::parse;

#[derive(Debug)]
struct FlowNode {
    id: String,
    parent: Option<String>,
    line_no: usize,
    record: Record,
}

pub fn render_file(path: &Path) -> Result<String> {
    let mut nodes = Vec::new();
    let mut seen = HashSet::new();
    let report = parse::parse_jsonl_file(path, |parsed| {
        let mut id = parsed
            .record
            .uuid
            .clone()
            .filter(|uuid| !uuid.is_empty())
            .unwrap_or_else(|| format!("line:{}", parsed.line_no));
        if !seen.insert(id.clone()) {
            id = format!("{id}#{}", parsed.line_no);
            seen.insert(id.clone());
        }

        nodes.push(FlowNode {
            id,
            parent: parsed
                .record
                .parent_uuid
                .clone()
                .filter(|parent| !parent.is_empty()),
            line_no: parsed.line_no,
            record: parsed.record,
        });
        Ok(())
    })?;

    let mut index_by_id = HashMap::with_capacity(nodes.len());
    for (index, node) in nodes.iter().enumerate() {
        index_by_id.insert(node.id.clone(), index);
    }

    let mut children = vec![Vec::<usize>::new(); nodes.len()];
    let mut roots = Vec::new();
    for (index, node) in nodes.iter().enumerate() {
        match node
            .parent
            .as_ref()
            .and_then(|parent| index_by_id.get(parent))
        {
            Some(parent_index) => children[*parent_index].push(index),
            None => roots.push(index),
        }
    }

    roots.sort_by_key(|index| nodes[*index].line_no);
    for child_indexes in &mut children {
        child_indexes.sort_by_key(|index| nodes[*index].line_no);
    }

    let mut out = String::new();
    out.push_str(&format!("flow: {}\n", path.display()));
    out.push_str(&format!(
        "records: {} malformed: {}\n",
        report.records, report.malformed
    ));
    for root in roots {
        render_node(root, 0, &nodes, &children, &mut out);
    }

    Ok(out)
}

fn render_node(
    index: usize,
    depth: usize,
    nodes: &[FlowNode],
    children: &[Vec<usize>],
    out: &mut String,
) {
    let node = &nodes[index];
    out.push_str(&"  ".repeat(depth));
    out.push_str(&format!(
        "{:>5} {} parent={} {}\n",
        node.line_no,
        short_id(&node.id),
        node.parent.as_deref().map(short_id).unwrap_or("-"),
        record_summary(&node.record)
    ));

    for child in &children[index] {
        render_node(*child, depth + 1, nodes, children, out);
    }
}

fn record_summary(record: &Record) -> String {
    let mut parts = Vec::new();
    parts.push(record.display_type().to_string());

    if let Some(timestamp) = record.timestamp.as_deref() {
        parts.push(timestamp.to_string());
    }

    if record.is_sidechain() {
        parts.push("[sidechain]".to_string());
    }

    if record.is_api_error() {
        parts.push("[API_ERROR]".to_string());
    }

    let tool_errors = record.tool_result_error_count();
    if tool_errors > 0 {
        parts.push(format!("[TOOL_ERROR x{tool_errors}]"));
    }

    if let Some(message) = record.message.as_ref() {
        if let Some(model) = message.model.as_deref() {
            parts.push(format!("model={model}"));
        }
    }

    let tool_names = record.tool_names();
    if !tool_names.is_empty() {
        parts.push(format!("tools={}", tool_names.join(",")));
    }

    if let Some(prompt) = record.human_prompt() {
        parts.push(format!("prompt=\"{}\"", preview(prompt, 96)));
    } else if let Some(prompt) = record.queue_prompt() {
        parts.push(format!("enqueue=\"{}\"", preview(&prompt, 96)));
    } else if record.record_type.as_deref() == Some("user") {
        let count = record
            .content_blocks()
            .map(|blocks| blocks.len())
            .unwrap_or(0);
        if count > 0 {
            parts.push(format!("tool_results={count}"));
        }
    } else if record.record_type.as_deref() == Some("summary") {
        if let Some(summary) = record.extra.get("summary").map(value_to_text) {
            parts.push(format!("summary=\"{}\"", preview(&summary, 96)));
        }
    } else if record.record_type.as_deref() == Some("queue-operation") {
        if let Some(operation) = record.operation.as_deref() {
            parts.push(format!("operation={operation}"));
        }
    }

    parts.join(" ")
}

fn short_id(id: &str) -> &str {
    id.get(..8).unwrap_or(id)
}

fn preview(value: &str, width: usize) -> String {
    let one_line = value.split_whitespace().collect::<Vec<_>>().join(" ");
    if one_line.chars().count() <= width {
        return one_line;
    }

    let mut out = one_line
        .chars()
        .take(width.saturating_sub(1))
        .collect::<String>();
    out.push('…');
    out
}
