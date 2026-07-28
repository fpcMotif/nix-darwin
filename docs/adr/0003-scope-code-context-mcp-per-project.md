# Remove docs-lookup MCP plugins globally, scope deepwiki/exa to per-project

Status: accepted (superseded in part — see Update)

Two Claude Code plugins shipped code-search MCP servers on the global surface:
an official single-server docs-lookup plugin, and a third-party `code-context`
plugin (three HTTP servers — a docs-lookup passthrough, `deepwiki-code-context`,
`exa-code-context`). Every globally-enabled MCP server costs context on every
turn (its tool schemas are discoverable), and the docs-lookup plugin was
unused. deepwiki and exa are genuinely useful, but only in repos where
dependency/code-context lookups matter — globally they are noise.

We disable **both plugins** on the global surface and move deepwiki + exa to
**per-project opt-in**. The docs-lookup plugin is dropped outright. This keeps
the always-on skill/MCP catalog lean while leaving the heavy lookups one
`.mcp.json` away in the projects that want them.

The lever is reproducible: `modules/home/claude.nix` →
`claudeDisableGlobalMcpPlugins` flips `enabledPlugins` off for any id listed
in `disabledClaudePlugins` on every `darwin-rebuild switch` (idempotent; only
rewrites `settings.json` when a flag actually changes), mirroring the
existing grill-me disable block. At the time of this decision, the plugins
stayed *installed* — a park, not an uninstall.

Per-project re-enablement uses a standalone project `.mcp.json`
(`templates/mcp/code-context.mcp.json`): deepwiki is keyless, exa reads
`EXA_API_KEY` via `${EXA_API_KEY}` expansion. Because these are plain HTTP
endpoints, they work independently of the (globally-disabled) `code-context`
plugin.

## Considered options

- **Keep the plugins global, strip only the docs-lookup plugin** — leaves
  deepwiki/exa globally enabled. Rejected: they are per-project concerns and
  add standing context cost everywhere.
- **Uninstall the plugins entirely** (remove from `installed_plugins.json` +
  cache). Rejected at the time: destructive and fights the repo's "park,
  don't delete" convention; a marketplace re-sync would reinstall them
  anyway. (Later done anyway for both plugins — see Update.)
- **Edit each plugin's `.mcp.json` in the cache** to remove individual servers.
  Rejected: more fragile than the single `enabledPlugins` toggle, reverts on
  plugin auto-update, and still loads the plugins' skills/commands.
- **Disable both via `enabledPlugins` + per-project `.mcp.json`** (chosen):
  one reproducible toggle, non-destructive, and the per-project path is
  decoupled from the plugin entirely.

## Consequences

- The global `~/.claude/CLAUDE.md` "DeepWiki MCP" guidance and the
  `/deep-research` workflow have no deepwiki server **globally**; they work only
  in repos that drop in the project `.mcp.json`. Those instructions live outside
  this repo and may want a note.
- The docs-lookup plugin is gone from every local Claude surface (CLI +
  Desktop). claude.ai connectors are account-side and unaffected by this repo.
- The `code-context` plugin's skills/agents/commands
  (`code-context:*`, `context-researcher`) also left the global picker while
  it was disabled — consistent with the lean-catalog goal.
- exa now depends on `EXA_API_KEY` in the environment rather than a key baked
  into the plugin cache.

## Update (2026-07-15)

Both plugins named above were later removed from this machine entirely
(uninstalled, not just disabled), so the "park, don't delete" choice above no
longer holds for either — `disabledClaudePlugins` in `claude.nix` is now
empty. The per-project `templates/mcp/code-context.mcp.json` opt-in is
unaffected: it was always a standalone `.mcp.json` with plain HTTP endpoints,
independent of either plugin.
