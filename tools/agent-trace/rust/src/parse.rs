use std::env;
use std::ffi::OsStr;
use std::fs::{self, File};
use std::io::{BufRead, BufReader};
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};

use crate::model::Record;

#[derive(Debug, Clone)]
pub struct TranscriptFile {
    pub project: String,
    pub path: PathBuf,
}

#[derive(Debug, Clone)]
pub struct ParsedRecord {
    pub line_no: usize,
    pub record: Record,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct ParseReport {
    pub lines: usize,
    pub records: usize,
    pub malformed: usize,
}

pub fn parse_jsonl_file<F>(path: &Path, mut on_record: F) -> Result<ParseReport>
where
    F: FnMut(ParsedRecord) -> Result<()>,
{
    let file = File::open(path).with_context(|| format!("opening {}", path.display()))?;
    let mut reader = BufReader::new(file);
    let mut line = String::new();
    let mut report = ParseReport::default();

    loop {
        line.clear();
        let bytes = reader
            .read_line(&mut line)
            .with_context(|| format!("reading {}", path.display()))?;
        if bytes == 0 {
            break;
        }

        report.lines += 1;
        let trimmed = line.trim_end_matches(['\r', '\n']);
        if trimmed.trim().is_empty() {
            report.malformed += 1;
            continue;
        }

        match serde_json::from_str::<Record>(trimmed) {
            Ok(record) => {
                report.records += 1;
                on_record(ParsedRecord {
                    line_no: report.lines,
                    record,
                })?;
            }
            Err(_) => report.malformed += 1,
        }
    }

    Ok(report)
}

pub fn discover_transcripts(root: &Path) -> Result<Vec<TranscriptFile>> {
    if root.is_file() {
        return Ok(if is_jsonl(root) {
            vec![TranscriptFile {
                project: project_name_for_file(root),
                path: root.to_path_buf(),
            }]
        } else {
            Vec::new()
        });
    }

    if !root.exists() {
        bail!("root does not exist: {}", root.display());
    }
    if !root.is_dir() {
        bail!("root is neither a directory nor a file: {}", root.display());
    }

    let mut transcripts = Vec::new();
    let entries = sorted_entries(root)?;
    let root_project = path_basename(root);
    let root_has_jsonl = entries.iter().any(|entry| {
        let path = entry.path();
        path.is_file() && is_jsonl(&path)
    });

    if root_has_jsonl {
        collect_jsonl_recursive(root, &root_project, &mut transcripts)?;
    } else {
        for entry in entries {
            let path = entry.path();
            if path.is_file() {
                if is_jsonl(&path) {
                    transcripts.push(TranscriptFile {
                        project: root_project.clone(),
                        path,
                    });
                }
                continue;
            }

            if path.is_dir() {
                let project = path_basename(&path);
                collect_jsonl_recursive(&path, &project, &mut transcripts)?;
            }
        }
    }

    transcripts.sort_by(|left, right| {
        left.project
            .cmp(&right.project)
            .then_with(|| left.path.cmp(&right.path))
    });
    Ok(transcripts)
}

fn collect_jsonl_recursive(
    dir: &Path,
    project: &str,
    transcripts: &mut Vec<TranscriptFile>,
) -> Result<()> {
    for entry in sorted_entries(dir)? {
        let path = entry.path();
        if path.is_file() {
            if is_jsonl(&path) {
                transcripts.push(TranscriptFile {
                    project: project.to_string(),
                    path,
                });
            }
        } else if path.is_dir() {
            collect_jsonl_recursive(&path, project, transcripts)?;
        }
    }

    Ok(())
}

fn sorted_entries(dir: &Path) -> Result<Vec<fs::DirEntry>> {
    let mut entries = fs::read_dir(dir)
        .with_context(|| format!("reading directory {}", dir.display()))?
        .collect::<std::result::Result<Vec<_>, _>>()
        .with_context(|| format!("reading entries from {}", dir.display()))?;
    entries.sort_by_key(|entry| entry.path());
    Ok(entries)
}

fn path_basename(path: &Path) -> String {
    path.file_name()
        .and_then(OsStr::to_str)
        .unwrap_or(".")
        .to_string()
}

pub fn expand_tilde(path: &Path) -> PathBuf {
    let raw = path.as_os_str().to_string_lossy();
    if raw == "~" {
        return env::var_os("HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| path.to_path_buf());
    }

    if let Some(rest) = raw.strip_prefix("~/") {
        if let Some(home) = env::var_os("HOME") {
            return PathBuf::from(home).join(rest);
        }
    }

    path.to_path_buf()
}

pub fn session_fallback(path: &Path) -> String {
    path.file_stem()
        .and_then(OsStr::to_str)
        .or_else(|| path.file_name().and_then(OsStr::to_str))
        .unwrap_or("unknown-session")
        .to_string()
}

fn is_jsonl(path: &Path) -> bool {
    path.extension().and_then(OsStr::to_str) == Some("jsonl")
}

fn project_name_for_file(path: &Path) -> String {
    path.parent()
        .and_then(Path::file_name)
        .and_then(OsStr::to_str)
        .unwrap_or(".")
        .to_string()
}
