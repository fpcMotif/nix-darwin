# CLAUDE.md — Claude adapter

## Claude

- **Develop**: Before choosing a shell command, running Python, or using version control, read `~/.claude/guidance/development.md`.
- **Documents**: Before writing an issue, specification, PRD, or analysis, read `~/.claude/guidance/human-documents.md`.

## Search

The first move of every search is fff or codedb. Both load on turn one and answer in one ranked, bounded call. `rg`, `fd`, and `ls` return raw lines that cost extra reads.

- **File name**: `mcp__fff__find_files` with one or two terms. Recent and git-dirty files rank first.
- **Symbol**: A definition or its callers go to `mcp__codedb__codedb_explain` with `name` and `project=<repo>`. One call returns the body and every call site, so no follow-up reads.
- **Identifier**: Where a name or string appears goes to `mcp__fff__grep`; `mcp__fff__multi_grep` takes its spellings.
- **Task**: `mcp__codedb__codedb_context` with `semantic=local` and `project=<repo>` orients a task in one bundle.
- **Folder**: `mcp__codedb__codedb_list_dir`, or `eza -la DIR` and `eza --tree -L 2 DIR`.
- **Jump**: `z NAME && COMMAND` runs a command in a frecent directory found by name.
- **Known path**: Read the span with offset and limit.
- **Exhaustive**: `rg` proves every mention, count, or absence. fff caps at 50 hits; codedb skips node_modules and files over 2 MiB.
- **Other repository**: fff searches the session root only. Pass that repository's `project` to codedb, or scope `rg` to it.
- **Detail**: Read `~/.claude/search-routing.md` for worked examples, traps, and measured evidence.
