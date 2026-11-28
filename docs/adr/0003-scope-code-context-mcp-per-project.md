# Scope the exa code-context MCP server per project

Status: accepted

Every MCP server on the global Claude Code surface loads its tool schemas into every session. The `exa` code-context server helps only in repositories that need external dependency and code-context lookups. We keep `exa` off the global Claude Code config and ship a per-project template at `templates/mcp/code-context.mcp.json`. That template uses direct HTTP and `${EXA_API_KEY}` expansion.

## Considered options

- **Register `exa` globally in user-scope Claude settings.** Rejected: every repository pays the per-turn context token cost to serve a few codebases.
- **Install `exa` via the upstream `code-context` Claude plugin.** Rejected: Claude plugins enable all bundled servers and skills together, and plugin updates overwrite cached edits.
- **Opt in per repository with a standalone `.mcp.json` template (chosen).** Costs zero global context and needs no plugin.

## Consequences and trade-offs

- Adopting `exa` in a repository requires copying `templates/mcp/code-context.mcp.json` to `.mcp.json`. The user must export `EXA_API_KEY` and approve the server once.
- Template edits do not propagate automatically to repositories that already copied the file.
- **Reversal trigger:** If Claude Code adds lazy on-demand MCP schema loading with zero idle token cost, revisit global registration.
