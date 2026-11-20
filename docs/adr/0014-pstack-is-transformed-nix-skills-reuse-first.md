# pstack comes from the Cursor plugin in Claude Code and from transformed Nix skills elsewhere, reuse first

Status: accepted (2026-09-08, amended 2026-11-20: Claude Code uses the `pstack@cursor-plugins` plugin)

## Context

pstack (Lauren Tan, `cursor/plugins/pstack`) is a Cursor plugin: 47 skills, 23 playbooks, helper programs, and two subagents, with Cursor-only spellings baked into the text (plugin-namespaced agent ids, Cursor model slugs, `~/.cursor/rules/pstack-models.mdc`, `/setup-pstack`, a `verify` skill that is a Cursor built-in). Two Claude Code ports exist. `michael-denyer/pstack-claude` keeps all 23 principles and re-applies documented substitutions on every upstream sync; `ericlitman/open-pstack` drops two principles and adds a dispatch layer.

The global catalog is code-dev-first (ADR-0017) and every catalog entry costs context on every session. Several pstack skills duplicate skills already installed: mattpocock `tdd`, `teach`, `prototype`, `wait-what`, `writing-for-agents`, `diagnosing-bugs`; the built-in `simplify`; the CLAUDE.md comment and writing rules.

## Decision

1. **Source, by harness**:
   - **Claude Code** gets pstack from the `pstack@cursor-plugins` plugin. `modules/home/claude.nix` seeds it as enabled and registers the `cursor-plugins` marketplace (`cursor/plugins`, `autoUpdate = true`). The plugin is the upstream Cursor tree. It is not pinned in `flake.lock`, and it updates outside `darwin-rebuild`.
   - **Other agents** get transformed skills from the flake input `pstack-claude` (the michael-denyer port). That input is pinned in `flake.lock` and bumped by the nightly auto-update like every light input.
2. **Shape**: `modules/home/claude/pstack.nix` builds each selected skill as a transformed Nix derivation in `pstackDrvs`. Each derivation rewrites its `SKILL.md` at build time and ships other files verbatim. `modules/home/claude.nix` publishes those derivations through `martin.agentSurface.skills` with `audience = "pickers"`. Claude Code hides them (`pstackPluginSkillIds` in `claudeHiddenSkillIds`), so only the plugin copy lists there.
3. **Scope, reuse first**: poteto-mode, the orchestration skills it routes to (how, why, architect, arena, swarm, interrogate, figure-it-out, benchmark-checklist, show-me-your-work, create-verification-skill, maintain-verification-skill), and the principles. Every pstack skill with an installed equivalent is left out and poteto-mode's trigger line is rewritten to name the equivalent: tdd and teach (mattpocock), deslop (`/simplify`), no-comments (CLAUDE.md comment rule), unslop and technical-writing (`human-documents.md` and CLAUDE.md Writing plus `writing-for-agents`), bro and ketchup (`wait-what`), thermo-nuclear reviews (`code-review`, `interrogate`, and `nuclear-cqr`), the Prototype playbook (`prototype`), `plugin-dev:skill-development` (`writing-for-agents`). Blast-radius, bot tooling, transcript mining, reflect, correct, and the port's PR extras are out.
4. **Principles as one module**: the 23 `principle-*` leaves become `pstack-principles`, built at eval time from the upstream leaves (frontmatter dropped, sibling links turned into section anchors). poteto-mode's index bullets keep the upstream ids; each is a section heading.
5. **Names the module cannot rewrite**: poteto-mode carries a "Names used in the playbooks" section mapping `verify`, `/deslop`, `/no-comments`, `unslop`, `/technical-writing`, the bundled `babysit` skill, `/tdd`, `skill-creator`, `thermo-nuclear-code-quality-review`, `~/.claude/pstack-models.md`, and leaf principle skills to what is installed here. Playbooks and references keep their upstream text and resolve through it.
6. **Models**: Claude model slugs become the Agent tool's aliases (`fable` = Fable 5.1, `opus` = Opus 5, `sonnet` = Sonnet 5, `haiku` = Haiku 4.5). `~/.claude/pstack-models.md` is a Nix-owned `home.file` generated from `pstackModelRoles`; pstack's own override contract makes it the one place model routing changes.
7. **Subagent**: The `pstack@cursor-plugins` plugin supplies the `poteto-agent` subagent, and Nix installs nothing under `~/.claude/agents`. `pstackAgentText` stays in `modules/home/claude/pstack.nix`, and `tests/unit/pstack-hygiene-test.nix` checks its description and principle-section rewrite. Nix does not install the port's session-start hook that mandates poteto-mode, so poteto-mode stays opt-in.
8. **Regression test**: `tests/unit/pstack-hygiene-test.nix` imports the same `pstack.nix` and asserts on the rewrite results against the pinned input: no plugin-only or slug residue, the expected rewrites present, section count equal to the upstream leaf count, the agent pointer rewritten, fifteen role lines. A port sync that rewords an anchor fails `nix flake check` on the nightly bump PR before it can merge.

## Consequences

- Outside Claude Code, one pstack module (`pstack-principles`) stands in for 23; the bundle holds 41 ids.
- Outside Claude Code, upstream edits flow through `nix flake update pstack-claude`; the transform is the only local divergence and the test names each rule it depends on.
- In Claude Code, the transforms, the reuse-first scope, and the principle merge do not apply. The plugin ships its full upstream id set with Cursor spellings, such as `/setup-pstack` and the `pstack:` agent namespace. The regression test does not cover the plugin copy.
- The read-only store means poteto-mode's `scripts/` (orch, watch-pr) cannot install their `node_modules` in place; the skill carries the copy-out note. A wrapper (review candidate F) stays open until those flows are used.
- Two references in non-SKILL files still say `pstack:poteto-agent` (one playbook, the Codex mapping doc). In Claude Code that id is the plugin's real agent. For other agents, the alias section resolves it.

## What would change this decision

- The port stops tracking upstream: revisit the source for other agents.
- The plugin copy in Claude Code drifts from the transformed copy in a way that matters, or its Cursor spellings misfire: move Claude Code back to the transformed skills and the Nix-installed `poteto-agent`.
- `programs.agent-skills` gains per-file transforms: retire the alias section and rewrite playbooks directly.
- A pstack skill left out here gains behaviour its installed equivalent lacks: add it, and add its id to the test's `installedIds`.
