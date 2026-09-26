# CLAUDE.md — Claude adapter

## Claude

- **Develop**: Before choosing a shell command, running Python or Rust, adding an environment variable, or using version control, read `~/.claude/guidance/development.md`.
- **Documents**: Before writing an issue, specification, PRD, analysis, ADR, or CONTEXT.md, read `~/.claude/guidance/human-documents.md`.
- **Workspaces**: Before creating a Git worktree or JJ workspace, read Parallel checkouts in `~/.claude/guidance/development.md`.

## Search

Search with fff and codedb first: one call returns a ranked, bounded answer.

- **Known path**: Read the needed span with offset and limit.
- **File name**: `mcp__fff__find_files` with one or two terms.
- **Identifier**: `mcp__fff__grep`; batch spellings in one `mcp__fff__multi_grep`.
- **Symbol**: `mcp__codedb__codedb_explain` with `name` and `project=<repo>`.
- **Call chain**: `mcp__codedb__codedb_callpath`.
- **Task**: `mcp__codedb__codedb_context` with `semantic=local` and `project=<repo>`.
- **Folder**: `mcp__codedb__codedb_list_dir` or `eza --tree -L 2 DIR`.
- **Other repo**: Pass its path as `project`; confirm the checkout before editing.
- **Trust**: Act on a result that answers the question.
- **Coverage**: Scoped `rg` confirms a full listing, count, or absence; state the scope.
- **Fallback**: After an MCP call fails, use scoped `rg`, `fd`, or Read, and name the failure.
- **Detail**: `~/.claude/search-routing.md` for unclear routing.
