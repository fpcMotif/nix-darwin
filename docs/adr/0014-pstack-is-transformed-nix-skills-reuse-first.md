# pstack comes from the Cursor plugin in Claude Code and from transformed Nix skills elsewhere, reuse first

Status: accepted

Upstream `pstack` (`cursor/plugins/pstack`) ships 47 skills, 23 principle leaves, playbooks, and subagents with Cursor-only names. Several of its skills duplicate skills already in our catalog (`tdd`, `teach`, `prototype`, `wait-what`, `writing-for-agents`, `diagnosing-bugs`, `simplify`, `code-review`). To avoid duplicate catalog noise while serving every agent harness:
1. **Claude Code** loads `pstack` from the `pstack@cursor-plugins` plugin (`autoUpdate = true`) and hides the Nix copies via `claudeHiddenSkillIds`.
2. **Other harnesses** get transformed derivations (`modules/home/claude/pstack.nix`) that reuse local skills, collapse 23 principles into `pstack-principles`, and route models via `~/.claude/pstack-models.md`.

## Considered options

- **Install all 47 upstream pstack skills verbatim into every harness.** Rejected: adds 23 separate principle entries and duplicate skills to every session, and leaves broken Cursor slugs outside Cursor.
- **Vendor a forked copy of pstack in this repository.** Rejected: manual forks drift; build-time string transforms over a pinned input fail fast in `unit-pstack-hygiene` when an upstream anchor changes.
- **Use the transformed Nix derivations in Claude Code too instead of the plugin.** Rejected for now: the operator enabled the upstream `pstack@cursor-plugins` plugin in Claude Code for direct upstream tracking.

## Consequences and trade-offs

- Claude Code sees the raw Cursor plugin (63+ IDs), while Codex, OMP, and Antigravity see the transformed bundle (41 IDs).
- Playbooks and helper scripts under `scripts/` live in the read-only Nix store for non-Claude harnesses; copy them out before installing `node_modules`.
- **Reversal trigger:** If Cursor spellings in `pstack@cursor-plugins` misfire in Claude Code, drop the plugin and use the transformed Nix derivations there too.
