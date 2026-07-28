# agent-trace Go

A stdlib-only Go CLI for streaming Claude Code JSONL transcripts under `~/.claude/projects`.

```sh
go build
./agent-trace stats --root ~/.claude/projects --format table
./agent-trace prompts --root ~/.claude/projects --grep 'bug' --min-len 20
./agent-trace flow ~/.claude/projects/<project>/<session>.jsonl
```

Commands match `../SCHEMA.md`: `stats` aggregates sessions, record types, tool uses, models, token totals, errors, and projects; `prompts` prints the first queued or human prompt per session; `flow` renders the `uuid`/`parentUuid` tree with sidechains, tool calls, and error markers.
