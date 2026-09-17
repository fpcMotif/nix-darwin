# AGENTS.md — Codex adapter

## Codex

- **Develop**: Read `~/.codex/guidance/development.md` for tool selection, code navigation, Python environments, or version-control conventions.
- **Configure**: Before changing Codex instructions, skills, profiles, MCP, or settings, read `~/.codex/guidance/setup.md`.
- **Edit**: Use `apply_patch` for file changes. Track a plan when dependencies or uncertainty require it.
- **Rules**: Command permissions live in `~/.codex/rules/default.rules` and fail closed.
- **Tools**: Use tools exposed in the current session. Translate examples to their available equivalents.
- **Skills**: Use the user’s named skill. Otherwise load the narrowest skill whose workflow helps the requested outcome.
- **Proof**: Tool configuration, discovery, and a successful harmless call establish separate facts.

## Search

The first move of every search is FFF or CodeDB. Each answers in one ranked, bounded call. `rg`, `fd`, and `ls` return raw lines that cost extra reads.

- **File name**: FFF `find_files` with one or two terms. Recent and git-dirty files rank first.
- **Symbol**: A definition or its callers go to CodeDB `codedb_explain` with `name` and `project=<repo>`. One call returns the body and every call site.
- **Identifier**: Where a name or string appears goes to FFF `grep`; `multi_grep` takes its spellings.
- **Call chain**: CodeDB `codedb_callpath` gives the shortest resolved chain from one symbol to another.
- **Task**: CodeDB `codedb_context` with `semantic=local` and `project=<repo>` orients a task in one bundle.
- **Folder**: CodeDB `codedb_list_dir`, or `eza -la DIR` and `eza --tree -L 2 DIR`.
- **Jump**: `z NAME && COMMAND` runs a command in a frecent directory found by name.
- **Exhaustive**: `rg` proves every mention, count, or absence. FFF caps at 50 hits; CodeDB skips node_modules and files over 2 MiB.
- **Other repository**: FFF searches the session root only. Pass that repository's `project` to CodeDB, or scope `rg` to it.
