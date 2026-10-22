# CLAUDE.md — Claude adapter

## Claude

- **Develop**: Before choosing a shell command, adding an environment variable, using version control, or setting up Git hooks, read `~/.claude/guidance/development.md`.
- **Languages**: Before writing or running TypeScript, Python, Go, or Rust, read that language's file: `~/.claude/guidance/languages/typescript.md`, `python.md`, `go.md`, or `rust.md`.
- **Documents**: Before writing an issue, specification, PRD, analysis, ADR, or GLOSSARY.md, read `~/.claude/guidance/human-documents.md`.
- **Workspaces**: Before creating a Git worktree or JJ workspace, read Parallel checkouts in `~/.claude/guidance/development.md`.
- **Shell guard**: Read with the Read tool or `bat -pp`. Find files with `fd`. Run Python with `uv run`. Change files with Edit or Write. Hooks deny `sed`, `find`, and bare `python`, even in bypass mode. They also deny file writes through `echo >`, heredocs, and inline scripts.
- **Ask box**: In the desktop app, write What I need from you in the text before `wrap_up`. Set `ask` to item 1 as one question, `actions` to its answers, and `blocked` when work stops. With nothing pending, omit `ask`, `actions`, and the section. Write the report after the call.

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

## Agents

- **Read-only**: Send searches and lookups to the Explore agent, which cannot edit. Mark review briefs read-only.
- **Haiku**: Pass the exact spans or candidates in the brief. Ask Haiku to classify or rewrite that input in place, with no file searching or reading.
- **Fork**: A fork sees this whole conversation, so its brief names the one task it owns.
- **Workflow**: In a workflow run, give each verifier a whole review dimension or file with all its findings. This keeps a run near its size guideline.
