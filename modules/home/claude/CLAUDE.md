# CLAUDE.md — Claude adapter

## Claude

- **Develop**: Before choosing a shell command, running Python or Rust, adding an environment variable, or using version control, read `~/.claude/guidance/development.md`.
- **Documents**: Before writing an issue, specification, PRD, or analysis, read `~/.claude/guidance/human-documents.md`.

## Search

fff is the default discovery tool. codedb is the default structural tool. `rg` is the verification tool. Read known paths directly; prefer one bounded call over chains of searches.

- **Known path**: Read the needed span with offset and limit.
- **File name**: `mcp__fff__find_files` with one or two terms.
- **Identifier**: `mcp__fff__grep`; batch related spellings with `mcp__fff__multi_grep`.
- **Symbol**: `mcp__codedb__codedb_explain` with `name` and `project=<repo>` for a definition and indexed callers.
- **Task**: For an unfamiliar task spanning modules, `mcp__codedb__codedb_context` with `semantic=local` and `project=<repo>`.
- **Folder**: `mcp__codedb__codedb_list_dir` or `eza --tree -L 2 DIR`.
- **Coverage**: Use scoped `rg` for text listings, counts, or absence checks. State scope and exclusions; do not truncate completeness checks.
- **Other repository**: Use its explicit `project` in codedb, or scoped `rg`. Confirm the checkout/worktree before editing.
- **Fallback**: When MCP is unavailable, warming up, or stale, use scoped `rg`, `fd`, or Read. Do not retry merely to obey routing.
- **Detail**: Read `~/.claude/search-routing.md` only for unclear routing or tool limits.

Ranked or indexed results do not guarantee every caller or repo-wide absence. Read additional source only when needed context is missing or freshness is uncertain.
