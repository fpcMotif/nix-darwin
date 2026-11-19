# AGENTS.md — shared adapter

User: f.

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
- **Fallback**: After the servers and the CLI fail, use scoped `rg`, `fd`, or direct reads, and name the failure.
