# Per-project MCP templates

Copy-paste MCP server definitions for **project-scoped** use. They are kept out
of the global Claude Code surface on purpose — see
[ADR 0003](../../docs/adr/0003-scope-code-context-mcp-per-project.md).

## `code-context.mcp.json` — exa

Claude Code does not register exa globally. To use exa in a specific repo:

1. Copy `code-context.mcp.json` into that repo's root as `.mcp.json`.
2. Delete the `$comment` key (it's just guidance; valid JSON has no comments).
3. Export `EXA_API_KEY` in your environment.
4. On first run, Claude Code prompts to approve the project's MCP servers — or
   add `"exa-code-context"` to `enabledMcpjsonServers` in that repo's
   `.claude/settings.json`.

This server is a plain HTTP endpoint, so it needs no plugin.
