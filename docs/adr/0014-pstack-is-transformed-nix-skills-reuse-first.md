# pstack is installed as transformed Nix skills from the Claude Code port, reuse first

Status: accepted (2026-09-08)

## Context

pstack (Lauren Tan, `cursor/plugins/pstack`) is a Cursor plugin: 47 skills, 23 playbooks, helper programs, and two subagents, with Cursor-only spellings baked into the text (plugin-namespaced agent ids, Cursor model slugs, `~/.cursor/rules/pstack-models.mdc`, `/setup-pstack`, a `verify` skill that is a Cursor built-in). Two Claude Code ports exist. `michael-denyer/pstack-claude` keeps all 23 principles and re-applies documented substitutions on every upstream sync; `ericlitman/open-pstack` drops two principles and adds a dispatch layer.

The global catalog is code-dev-first (ADR-0008) and every catalog entry costs context on every session. Several pstack skills duplicate skills already installed: mattpocock `tdd`, `teach`, `prototype`, `wait-what`, `writing-for-agents`, `diagnosing-bugs`; the built-in `simplify`; ripwire's edit check; the CLAUDE.md comment and writing rules.

## Decision

1. **Source**: the flake input `pstack-claude` (the michael-denyer port), pinned in `flake.lock` and bumped by the nightly auto-update like every light input. Not the upstream Cursor tree (its playbooks and references carry Cursor spellings the module cannot rewrite) and not a Claude Code plugin install (unpinned, all 54 ids, duplicates against the bundle).
2. **Shape**: plain skills through `programs.agent-skills`, defined in `modules/home/claude/pstack.nix`. Each selected skill is an `explicit` entry with a `transform`, a pure string rewrite of its SKILL.md at build time. Other files in a skill ship verbatim.
3. **Scope, reuse first**: poteto-mode, the orchestration skills it routes to (how, why, architect, arena, swarm, interrogate, figure-it-out, unslop, show-me-your-work, create-verification-skill, maintain-verification-skill), and the principles. Every pstack skill with an installed equivalent is left out and poteto-mode's trigger line is rewritten to name the equivalent: tdd and teach (mattpocock), deslop (`/simplify`), no-comments (CLAUDE.md comment rule), technical-writing (CLAUDE.md Writing Style plus `writing-for-agents`), bro (`wait-what`), blast-radius (`rw --edit-check`), the Prototype playbook (`prototype`), `plugin-dev:skill-development` (`writing-for-agents`; ADR-0008 keeps skill-creator off the global catalog). Bot tooling, transcript mining, and the port's PR extras are out.
4. **Principles as one module**: the 23 `principle-*` leaves become `pstack-principles`, built at eval time from the upstream leaves (frontmatter dropped, sibling links turned into section anchors). poteto-mode's index bullets keep the upstream ids; each is a section heading.
5. **Names the module cannot rewrite**: poteto-mode carries a "Names used in the playbooks" section mapping `verify`, `/deslop`, `/no-comments`, `/technical-writing`, the bundled `babysit` skill, `/tdd`, `skill-creator`, `~/.claude/pstack-models.md`, and leaf principle skills to what is installed here. Playbooks and references keep their upstream text and resolve through it.
6. **Models**: Claude model slugs become the Agent tool's aliases (`fable` = Fable 5.1, `opus` = Opus 5, `sonnet` = Sonnet 5, `haiku` = Haiku 4.5). `~/.claude/pstack-models.md` is a Nix-owned `home.file` generated from `pstackModelRoles`; pstack's own override contract makes it the one place model routing changes.
7. **Subagent**: `poteto-agent` is installed under `~/.claude/agents` from the input through a `writeText` that rewrites its description into a context pointer and its principle instruction to the section model. The port's session-start hook that mandates poteto-mode for every non-trivial task is not installed; poteto-mode is opt-in.
8. **Tripwire**: `tests/unit/pstack-hygiene-test.nix` imports the same `pstack.nix` and asserts on the rewrite results against the pinned input: no plugin-only or slug residue, the expected rewrites present, section count equal to the upstream leaf count, the agent pointer rewritten, fifteen role lines. A port sync that rewords an anchor fails `nix flake check` on the nightly bump PR before it can merge.

## Consequences

- One pstack module in the catalog (`pstack-principles`) instead of 23; the bundle holds 41 ids.
- Upstream edits flow through `nix flake update pstack-claude`; the transform is the only local divergence and the test names each rule it depends on.
- The read-only store means poteto-mode's `scripts/` (orch, watch-pr) cannot install their `node_modules` in place; the skill carries the copy-out note. A wrapper (review candidate F) stays open until those flows are used.
- Two references in non-SKILL files still say `pstack:poteto-agent` (one playbook, the Codex mapping doc); the alias section resolves them.

## What would change this decision

- The port stops tracking upstream, or upstream ships a Claude Code plugin with bare agent ids and alias model names: revisit the source.
- `programs.agent-skills` gains per-file transforms: retire the alias section and rewrite playbooks directly.
- A pstack skill left out here gains behaviour its installed equivalent lacks: add it, and add its id to the test's `installedIds`.
