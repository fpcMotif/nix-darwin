# Domain docs

How the engineering skills consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`GLOSSARY.md`** at the repo root.
- **`docs/adr/`** for ADRs that touch the area you are about to work in.

If any of these files do not exist, **proceed silently**. Do not flag their absence or suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions get resolved.

## File structure

This repo is single-context:

```
/
├── GLOSSARY.md
├── docs/adr/
│   └── 0001-darwin-baseline-favors-quiet-secure-defaults.md
└── modules/, hosts/, pkgs/, lib/, ...
```

## Use the glossary's vocabulary

When your output names a domain concept in an issue, refactor, or test, use the term from `GLOSSARY.md`. Do not drift to synonyms the glossary avoids.

If a concept is missing from the glossary, reconsider whether the project uses that language. If it is a real gap, record it with `/domain-modeling`.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than overriding it silently:

> _Contradicts ADR-0007 (event-sourced orders), worth reopening because…_
