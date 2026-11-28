# Skill curation stays separate lists, not one `skillPolicy` table

Status: accepted

`modules/home/claude/skill-curation.nix` curates upstream `mattpocock-skills` with three flat lists (`disabledMattpocockSkills`, `leanExcludedMattpocockSkills`, and `removedSkillIds`). The module derives `excludedSkillIds` and `enabledMattpocockSkills` from those three lists. We keep these three lists separate instead of merging them into a single per-skill `skillPolicy` table.

## Considered options

- **Replace the three lists with one `skillPolicy` attribute set and a `compile` function.** Rejected: `compile` reduced to a trivial `filterAttrs`, scattered group rationales, collided with `GLOSSARY.md` terms, and omitted `skills.explicit`.
- **Keep three separate lists with group-level comments (chosen).** States each group's rationale once and lets `unit-skill-hygiene` check membership directly.

## Consequences and trade-offs

- Moving a skill between curation buckets requires editing two lists in `skill-curation.nix` rather than changing one status field.
- Individual skills inside a list share their list's top-level comment unless given an inline comment.
- **Reversal trigger:** If curation rules grow per-skill logic beyond `filterAttrs` and adopt `GLOSSARY.md` terms (`parked`, `removed`), revisit a unified table.
