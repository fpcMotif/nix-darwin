# Development routing — Claude adapter

## Claude tools

- **Edit**: Create files with Write. Change existing text with exact Edit anchors.
- **Batch**: Submit independent Edits together. Use one Edit per site.
- **Transform**: Dry-run structural replacements with `sg`, then apply them with `sg -U`.
- **Hooks**: Shell guards enforce file-edit and Python routes, including bypass mode.
- **Timeout**: Use 120 seconds for tests, 30 seconds for networks, and 600 seconds for Nix builds.
- **Background**: `run_in_background` returns a task ID and output path and re-invokes this session when the job exits. `Read` that file for a reason, not to wait.
- **Condition**: For readiness without a completion event, arm `Monitor` with a bounded until-loop. Foreground `sleep` is blocked.
- **Lifetime**: A foreground subagent's shell job stops at its final response. Under `claude -p`, background jobs end about five seconds after the final result. Finish required shell work before either point.
- **Search**: The Search section of `~/.claude/CLAUDE.md` names the tool for each case.
- **Words**: Use `rw --for="TERMS"` when no file, identifier, or symbol name is known yet.
- **Spans**: An `rg` line hit drops an item's wrapped lines. Read the span it lands in.
- **Review**: Use `code-review`, `ripwire-change-check`, `better-github-skill`, and `hunk` for their named branches.
