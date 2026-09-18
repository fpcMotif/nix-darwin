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

FFF is the default discovery tool. CodeDB is the default structural tool. `rg` is the verification tool. Read known paths directly; prefer one bounded call over chains of searches.

- **Known path**: Read the needed span directly.
- **File name**: FFF `find_files` with one or two terms; without the server, `codedb <repo> file NAME`.
- **Identifier**: FFF `grep`; batch related spellings with `multi_grep`.
- **Symbol**: CodeDB `codedb_explain` with `name` and `project=<repo>` for definition and indexed callers; without the server, `codedb <repo> explain SYM`.
- **Call chain**: CodeDB `codedb_callpath` for the resolved chain between symbols; without the server, `codedb <repo> callpath FROM TO`.
- **Task**: For an unfamiliar task spanning modules, CodeDB `codedb_context` with `semantic=local` and `project=<repo>`.
- **Folder**: CodeDB `codedb_list_dir` or `eza --tree -L 2 DIR`.
- **Coverage**: Use scoped `rg` for text listings, counts, or absence checks. State scope and exclusions; do not truncate completeness checks.
- **Other repository**: Use its explicit `project` in CodeDB, or scoped `rg`. Confirm the checkout/worktree before editing.
- **Fallback**: When MCP is unavailable, warming up, or stale, use CLI `codedb`, scoped `rg`, `fd`, or direct reads. Do not retry merely to obey routing.

Ranked or indexed results do not guarantee every caller or repo-wide absence. Read additional source only when needed context is missing or freshness is uncertain.
