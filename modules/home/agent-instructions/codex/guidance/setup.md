# Codex setup ownership

Read before changing Codex instructions, skills, profiles, plugins, or MCP configuration.

## Layered ownership

Nix manages machine defaults in `/etc/codex/config.toml`.
Codex owns writable user overrides in `~/.codex/config.toml`.
User model, reasoning, project-trust, plugin, and UI choices persist in that user layer.
AGENTS.md, guidance, and named profiles remain Home Manager symlinks.
Edit Nix defaults and linked files in `~/nix-config/modules/home/agent-instructions/`, then rebuild.
The shared LSP section comes from `~/nix-config/modules/shared/codex-lsp.nix`.
Personal skills live in the repository's shared skill sources; native plugin skills stay with their installers.
Plugin caches and credentials remain writable runtime state.
Put durable machine defaults in Nix. Let Codex write personal overrides without activation reconciliation.

## Put each rule in one place

| Responsibility | Authoritative location |
| --- | --- |
| Cross-task behavior and task routing | `~/.codex/AGENTS.md` |
| Conditional personal conventions | `~/.codex/guidance/` |
| Repository conventions | The repository's instruction files |
| Task-specific procedure | The selected skill's `SKILL.md` and referenced files |
| Semantic job and model routing | `~/nix-config/modules/shared/agent-model-routing.nix` |
| Machine defaults and MCP launch configuration | `/etc/codex/config.toml` |
| Model, reasoning, trust, plugin, and UI overrides | `~/.codex/config.toml` |
| Named runtime overrides | `~/.codex/<name>.config.toml` |
| Command permission rules | `~/.codex/rules/default.rules` |
| Available actions and argument contracts | Tools exposed in the current session |

AGENTS.md supplies policy; skills supply procedures; MCP tools perform actions.
Keep configuration values in configuration files. Read them when needed instead of copying them into instructions.

Shared agent wording lives in `~/nix-config/modules/home/agent-instructions/shared/`.
`render-agent-guide.nix` combines those blocks with the Claude, Codex, OMP, and general host adapters.
Edit a shared rule there. Keep native tool names and runtime behavior in the matching host adapter.

Codex named profiles use the installed CLI's `--profile` contract and generated `<name>.config.toml` files.
Change their semantic jobs in `agent-model-routing.nix`; do not edit rendered profiles.
Legacy `[profiles.<name>]` tables conflict with these files and prevent profile loading.
Verify each changed profile with `codex -p <name> mcp list`; this checks configuration, not server readiness.

## Skill ownership

Skills may come from `~/.agents/skills`, `~/.codex/skills`, or installed plugins.
Before editing a skill, resolve its path and inspect its ownership.

- Nix store targets are generated and immutable. Change the owning source when a durable update is requested.
- Plugin caches belong to their plugin. Use the plugin's update workflow for durable changes.
- Two discovery paths can point to one implementation. Compare resolved paths and contents before treating them as duplicate maintenance.
- Similar descriptions do not establish interchangeable behavior. Read the contracts before merging or disabling skills.
- Add personal conventions here rather than copying a managed skill into a competing local version.

## Tool selection

For ordinary UI work, select the relevant `better-*` skill for layout, typography, color, accessibility, copy, or polish.
Explicit requests for another design skill take precedence; load its distinct requirements without repeating equivalent audits.

Use `development.md` for file search and code navigation.
Use ripwire for specialized analysis when it answers an additional question; avoid repeating orientation through both tools.
Use file-search tools for file discovery and exact text evidence when that is the question.
Use remote documentation tools for remote repository questions; distinguish that evidence from the local checkout.
Use the relevant browser or desktop skill for live interaction, then follow the exposed tool contract.
Treat tool names in older skill examples as examples, not proof those tools are available in this session.

If a configured MCP tool is absent, inspect startup diagnostics before changing the server definition.
Executable existence, configuration loading, tool discovery, and successful calls establish different facts; report them separately.
Verify enabled servers with initialization, nonempty tool discovery, and a harmless call through the harness when available.
Direct protocol probes establish server behavior; they do not prove the current harness exposes those tools.

## Change and verify

1. Read both configuration layers and their owning source. Preserve a backup before structural edits.
2. Change durable defaults in Nix. Change personal choices through Codex or the writable user file.
3. Verify precedence, configuration syntax, file writability, and the affected runtime behavior.
4. Report what changed and which checks ran. Treat a settings change as distinct from a live-session reload.
