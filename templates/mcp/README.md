# Per-project MCP templates

Copy-paste MCP server definitions for **project-scoped** use. They are kept out
of the global Claude Code surface on purpose — see
[ADR 0003](../../docs/adr/0003-scope-code-context-mcp-per-project.md).

## `code-context.mcp.json` — deepwiki + exa

context7, deepwiki, and exa are disabled globally
(`modules/home/claude.nix` → `claudeDisableGlobalMcpPlugins`). To use deepwiki /
exa in a specific repo:

1. Copy `code-context.mcp.json` into that repo's root as `.mcp.json`.
2. Delete the `$comment` key (it's just guidance; valid JSON has no comments).
3. Export `EXA_API_KEY` in your environment (deepwiki needs no key).
4. On first run, Claude Code prompts to approve the project's MCP servers — or
   add `"deepwiki-code-context"` / `"exa-code-context"` to
   `enabledMcpjsonServers` in that repo's `.claude/settings.json`.

These servers are plain HTTP endpoints, so they work independently of the
(now globally-disabled) `code-context` plugin.
