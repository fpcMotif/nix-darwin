# AGENTS.md — shared adapter

User: f.

- **Develop**: Before choosing a shell command, running Python or Rust, adding an environment variable, or using version control, read `~/.config/agent-guidance/development.md`.
- **Test**: Before writing a test, choosing a technique beyond E2E, or recording a test artifact, read `~/.config/agent-guidance/testing.md`.

## Search

FFF is the default discovery tool. CodeDB is the default structural tool. `rg` is the verification tool. Read known paths directly; prefer one bounded call over chains of searches.

- **Known path**: Read the needed span directly.
- **File name**: FFF `find_files` with one or two terms; without the server, `codedb <repo> file NAME`.
- **Identifier**: FFF `grep`; batch related spellings with `multi_grep`.
- **Symbol**: CodeDB `codedb_explain` with `project=<repo>` for definition and indexed callers; without the server, `codedb <repo> explain SYM`.
- **Task**: For an unfamiliar task spanning modules, CodeDB `codedb_context` with `semantic=local`; without the server, `codedb <repo> context --local TASK`.
- **Folder**: CodeDB `codedb_list_dir` or `eza --tree -L 2 DIR`.
- **Coverage**: Use scoped `rg` for text listings, counts, or absence checks. State scope and exclusions; do not truncate completeness checks.
- **Other repository**: Use its explicit `project` in CodeDB, or scoped `rg`. Confirm the checkout/worktree before editing.
- **Fallback**: When MCP is unavailable, warming up, or stale, use CLI `codedb`, scoped `rg`, `fd`, or direct reads. Do not retry merely to obey routing.

Ranked or indexed results do not guarantee every caller or repo-wide absence. Read additional source only when needed context is missing or freshness is uncertain.
