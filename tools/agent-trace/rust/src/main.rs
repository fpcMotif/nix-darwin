mod flow;
mod model;
mod parse;
mod prompts;
mod stats;

use std::io::{self, Write};
use std::path::PathBuf;

use anyhow::Result;
use clap::{Parser, Subcommand, ValueEnum};

#[derive(Debug, Clone, Copy, ValueEnum)]
enum OutputFormat {
    Json,
    Table,
}

#[derive(Debug, Parser)]
#[command(name = "agent-trace")]
#[command(about = "Analyze Claude Code JSONL session transcripts", version)]
struct Cli {
    #[arg(
        long,
        global = true,
        value_name = "PATH",
        default_value = "~/.claude/projects"
    )]
    root: PathBuf,

    #[arg(long, global = true, value_enum, default_value_t = OutputFormat::Table)]
    format: OutputFormat,

    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Aggregate transcript counts, tools, models, tokens, and projects.
    Stats,

    /// Print the first human prompt per session.
    Prompts {
        /// Case-insensitive substring filter applied to the full prompt text.
        #[arg(long = "grep", value_name = "PAT")]
        grep: Option<String>,

        /// Minimum prompt length in Unicode scalar values.
        #[arg(long = "min-len", default_value_t = 0)]
        min_len: usize,
    },

    /// Render the uuid/parentUuid tree for one transcript file.
    Flow {
        #[arg(value_name = "session.jsonl")]
        session: PathBuf,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let root = parse::expand_tilde(&cli.root);

    match cli.command {
        Command::Stats => {
            let report = stats::collect(&root)?;
            let output = match cli.format {
                OutputFormat::Json => format!("{}\n", serde_json::to_string_pretty(&report)?),
                OutputFormat::Table => stats::render_table(&report),
            };
            write_stdout(&output)?;
        }
        Command::Prompts { grep, min_len } => {
            let hits = prompts::collect(&root, grep.as_deref(), min_len)?;
            let output = match cli.format {
                OutputFormat::Json => format!("{}\n", serde_json::to_string_pretty(&hits)?),
                OutputFormat::Table => prompts::render_table(&hits),
            };
            write_stdout(&output)?;
        }
        Command::Flow { session } => {
            let session = parse::expand_tilde(&session);
            let output = flow::render_file(&session)?;
            write_stdout(&output)?;
        }
    }

    Ok(())
}

fn write_stdout(output: &str) -> Result<()> {
    let mut stdout = io::stdout().lock();
    match stdout
        .write_all(output.as_bytes())
        .and_then(|_| stdout.flush())
    {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == io::ErrorKind::BrokenPipe => Ok(()),
        Err(error) => Err(error.into()),
    }
}
