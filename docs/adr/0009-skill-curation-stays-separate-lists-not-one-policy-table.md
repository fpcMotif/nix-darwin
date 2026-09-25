# Skill curation stays separate lists, not one `skillPolicy` table

Status: accepted

`modules/home/claude.nix` curates the mattpocock bundle with three hand-written lists:

- `disabledMattpocockSkills`: skills turned off everywhere, including the Claude plugin surface.
- `leanExcludedMattpocockSkills`: niche skills trimmed from discovery. It is empty and kept for a future bucket.
- `removedSkillIds`: skills dropped from every source. Each rebuild deletes their stale copies.

`excludedSkillIds` and `enabledMattpocockSkills` are derived from these lists.

We keep the lists separate. An architecture review (Handoff E, 2026-07-02) proposed one `skillPolicy` attrset instead. Each skill would get a `status` and a `reason`. One compile function would derive the enabled set and own the sweep declarations. The proposal set its own refutation bar: if that function ends up a trivial `filterAttrs`, the candidate fails.

## Why

- **The compile function is a trivial filter.** The review's `nix eval` of the proposed `compile` over a hand-built table reproduced the hand-written lists byte for byte. The proposal credited `compile` with the duplicate-id rule. That throw lives in the agent-skills flake input (`lib/sources.nix`), not in this repo. The two sweeps already share one body: `mkSessionSweep` takes the step that differs as `cacheAction`.
- **A per-entry `reason` would scatter the rationale.** Each list states once, in the comment above it, why its whole group is excluded. Per-skill strings would make a reader re-cluster them to recover that.
- **The status names collide with CONTEXT.md.** The proposal's `disabled` status is what CONTEXT.md calls a **Parked skill**. `claudeDisableGrillSkills` moves each disabled skill's Claude Desktop cache copy into a sibling `skills-disabled/` directory. `removed` matches the glossary's "removed from source filters". `lean` has no glossary term. One enum cannot absorb these without renaming a pinned term.
- **The table could never hold all curation.** Skills wired one by one carry what a status table cannot. `web-browser` names a source and a dependency list in `skills.explicit`. Each pstack skill carries a build-time `transform` closure in `modules/home/claude/pstack.nix`. Those stay hand-written either way.

## What would change this decision

- A proposal that uses CONTEXT.md's terms exactly (`parked`, not `disabled`), defines or drops `lean`, and keeps the group-level comments. Re-evaluate the second and third reasons against it.
- A list gaining logic beyond membership, so that a compile step does real work. Re-run the deletion test.
