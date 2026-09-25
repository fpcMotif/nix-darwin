# AGENTS.md — Codex adapter

## Codex

- **Develop**: Read `~/.codex/guidance/development.md` for tool selection, code navigation, Python or Rust environments, environment variables, or version-control conventions.
- **Documents**: Before writing an issue, specification, PRD, analysis, ADR, or CONTEXT.md, read `~/.codex/guidance/human-documents.md`.
- **Configure**: Before changing Codex instructions, skills, profiles, MCP, or settings, read `~/.codex/guidance/setup.md`.
- **Edit**: Use `apply_patch` for file changes. Track a plan when dependencies or uncertainty require it.
- **Rules**: Command permissions live in `~/.codex/rules/default.rules` and fail closed.
- **Tools**: Use tools exposed in the current session. Translate examples to their available equivalents.
- **Skills**: Use the user’s named skill. Otherwise load the narrowest skill whose workflow helps the requested outcome.
- **Proof**: Tool configuration, discovery, and a successful harmless call establish separate facts.

## Search

Search with FFF and CodeDB first: one call returns a ranked, bounded answer.

- **Known path**: Read the needed span directly.
- **File name**: FFF `find_files` with one or two terms.
- **Identifier**: FFF `grep`; batch spellings in one `multi_grep`.
- **Symbol**: CodeDB `codedb_explain` with `name` and `project=<repo>`.
- **Call chain**: CodeDB `codedb_callpath`.
- **Task**: CodeDB `codedb_context` with `semantic=local` and `project=<repo>`.
- **Folder**: CodeDB `codedb_list_dir` or `eza --tree -L 2 DIR`.
- **Other repo**: Pass its path as `project`; confirm the checkout before editing.
- **Trust**: Act on a result that answers the question.
- **Coverage**: Scoped `rg` confirms a full listing, count, or absence; state the scope.
- **Fallback**: After an MCP call fails, use the `codedb` CLI (`codedb <repo> explain SYM`), then scoped `rg`, `fd`, or direct reads, and name the failure.
