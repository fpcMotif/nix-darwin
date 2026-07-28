# agent-trace (Rust)

Rust CLI scaffold for streaming analysis of Claude Code JSONL transcripts under `~/.claude/projects`.

## Build

```bash
cargo build --release
```

## Usage

```bash
agent-trace [--root PATH] [--format json|table] <command>
```

Commands:

```bash
agent-trace stats --root ~/.claude/projects --format table
agent-trace prompts --root ~/.claude/projects --grep convex --min-len 20
agent-trace flow ~/.claude/projects/<project-slug>/<session-uuid>.jsonl
```

Notes:

- `stats` aggregates sessions, records by type, tool-use names, models, token totals, API/tool-result errors, and per-project counts.
- `prompts` prints the first queued prompt per session, falling back to the first non-meta user string.
- `flow` renders the `uuid`/`parentUuid` tree for one JSONL transcript, marking sidechains, tool-use names, and error records.
- Parsing is streaming line-by-line; malformed JSONL lines are skipped and counted.
