# Development routing — Claude adapter

## Claude tools

- **Edit**: Create files with Write. Change existing text with exact Edit anchors.
- **Batch**: Submit independent Edits together. Use one Edit per site.
- **Transform**: Dry-run structural replacements with `sg`, then apply them with `sg -U`.
- **Hooks**: Shell guards enforce file-edit and Python routes, including bypass mode.
- **Timeout**: Use 120 seconds for tests, 30 seconds for networks, and 600 seconds for Nix builds.
- **Search**: The Search section of `~/.claude/CLAUDE.md` names the tool for each case.
- **Words**: Use `rw --for="TERMS"` when no file, identifier, or symbol name is known yet.
- **Spans**: An `rg` line hit drops an item's wrapped lines. Read the span it lands in.
- **Review**: Use `code-review`, `ripwire-change-check`, `better-github-skill`, and `hunk` for their named branches.
