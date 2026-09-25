# Scope the exa code-context MCP server per project

Status: accepted

Each MCP server enabled on the global Claude Code surface costs context on every turn. Its tool schemas stay discoverable in every session. The exa code-context server helps only in repos where dependency and code-context lookups matter. Elsewhere it is noise.

So Claude Code does not register exa globally. A project opts in with a standalone `.mcp.json` copied from `templates/mcp/code-context.mcp.json`. The entry is a plain HTTP endpoint, so the template depends on no plugin. exa reads `EXA_API_KEY` through `${EXA_API_KEY}` expansion.

This covers the local Claude Code surface, CLI and Desktop. claude.ai connectors are account-side, and this repo does not manage them.

## Considered options

- **Register exa globally**, as a user-scope MCP server or through a plugin. Rejected: every repo pays its context cost to serve a few.
- **Get exa from the `code-context` plugin**, which bundled it with other servers. Rejected: enabling a plugin is all-or-nothing, so it also loads the other servers and the plugin's skills, agents, and commands. Editing its cached `.mcp.json` to drop servers reverts on every plugin update. The plugin is uninstalled.
- **A per-project `.mcp.json` from a template** (chosen): no global cost, and no dependency on a plugin.

## Consequences

- A repo that wants exa copies the template, then approves the server or lists it under `enabledMcpjsonServers` in its `.claude/settings.json`.
- exa depends on `EXA_API_KEY` in the environment.
- To keep a plugin that bundles MCP servers installed but off the global surface, add its id to `disabledClaudePlugins` in `modules/home/claude.nix`. The settings reconciler then sets its `enabledPlugins` flag to `false` on every switch.
