# agent-trace Python CLI

Stdlib-only Python 3.11+ implementation of the `agent-trace` transcript contract in `../SCHEMA.md`.

## Layout

- `agent_trace/__main__.py` — argparse CLI with `stats`, `prompts`, and `flow` subcommands.
- `agent_trace/parse.py` — streaming JSONL parser and light dict accessors.
- `agent_trace/stats.py` — aggregate session, record, tool, model, token, error, and project statistics.
- `agent_trace/prompts.py` — first human prompt per session (`queue-operation enqueue` preferred over user-string fallback).
- `agent_trace/flow.py` — `uuid`/`parentUuid` tree renderer with sidechain, tool-use, and error markers.
- `agent-trace` — thin executable wrapper around `python3 -m agent_trace`.

## Usage

From this directory:

```sh
python3 -m agent_trace stats --root ~/.claude/projects --format table
python3 -m agent_trace prompts --root ~/.claude/projects --grep refactor --min-len 40
python3 -m agent_trace flow ~/.claude/projects/<project>/<session>.jsonl
```

Or via the wrapper from any directory:

```sh
./agent-trace stats --root ~/.claude/projects --format json
```

If the package is not on `PYTHONPATH`, use the wrapper or run `python3 -m agent_trace` from this `python/` directory.
