# AGENTS.md — shared adapter

User: f.

- **Develop**: Before choosing a shell command, running Python or Rust, adding an environment variable, or using version control, read `~/.config/agent-guidance/development.md`.
- **Documents**: Before writing an issue, specification, PRD, analysis, ADR, or CONTEXT.md, read `~/.config/agent-guidance/human-documents.md`.

## Search

Search with FFF and CodeDB first: one call returns a ranked, bounded answer. Without the servers, the `codedb` CLI answers the same: `codedb <repo> file NAME`, `explain SYM`, `callpath FROM TO`, `context --local TASK`.

- **Known path**: Read the needed span directly.
- **File name**: FFF `find_files` with one or two terms.
- **Identifier**: FFF `grep`; batch spellings in one `multi_grep`.
- **Symbol**: CodeDB `codedb_explain` with `project=<repo>`.
- **Call chain**: CodeDB `codedb_callpath`.
- **Task**: CodeDB `codedb_context` with `semantic=local`.
- **Folder**: CodeDB `codedb_list_dir` or `eza --tree -L 2 DIR`.
- **Other repo**: Pass its path as `project`; confirm the checkout before editing.
- **Trust**: Act on a result that answers the question.
- **Coverage**: Scoped `rg` confirms a full listing, count, or absence; state the scope.
- **Fallback**: After the servers and the CLI fail, use scoped `rg`, `fd`, or direct reads, and name the failure.
