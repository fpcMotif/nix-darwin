# Skill curation stays four lists, not one `skillPolicy` table

Status: refuted (not deferred — see "What would change this decision" for the one exception)

## The candidate

Handoff E (`skill-policy-table`, architecture review 2026-07-02) proposed collapsing
`modules/home/claude.nix`'s four skill-curation lists — `disabledMattpocockSkills`,
`leanExcludedMattpocockSkills`, `removedSkillIds`, `transformedMattpocockSkills` — into one
`skillPolicy` attrset with a `status` field per skill (`disabled` / `lean` / `removed` /
`enabled`), compiled by a single function that would also own `enabledMattpocockSkills`'s
derivation and the `mkSkillTargetRm` / `mkSessionSweep` sweep declarations. The handoff set its
own refutation bar explicitly: "If the function ends up a trivial `filterAttrs`, the candidate is
refuted" (handoff-E, adversarial question 1).

## Decision

Refuted as scoped. This is a final decision on the `skillPolicy` compile-function shape
Handoff E describes, not a deferral of the general idea — three of the four adversarial
questions fail for reasons independent of sequencing (Q1–Q3 below). Only Q4 (ordering with
Handoff A) is a sequencing consideration, and Handoff A landing does not resolve Q1–Q3.

## Reasoning (from adversarial review)

**Q1 — deletion test fails; the handoff's own justification is wrong.** A `nix eval` reducing
`compile(['disabled'])` and `compile(['removed'])` against a hand-built `skillPolicy` attrset
produced byte-identical output to today's hand-written `disabledMattpocockSkills` (claude.nix:220)
and `removedSkillIds` (claude.nix:235-236). That trips the handoff's own bar: the function is a
trivial `filterAttrs`. The handoff attributes non-triviality to `compile()` "owning the
duplicate-id collision rule," but that throw (`"agent-skills: duplicate skill id..."`) lives at
`references/agent-skills-nix-master/lib/default.nix:121` — inside the vendored, out-of-scope
agent-skills library — not in `claude.nix`. The one real, non-trivial consumer,
`skills.explicit`'s transform closures and per-skill CLI-dependency lists (claude.nix:620-635),
cannot be represented in a status/reason table at all (transforms are Nix closures like
`appendKarpathy grillKarpathyFooter`, not data), so `transformedMattpocockSkills`/`explicit` stays
hand-written regardless of whether the other three lists move into a table. The only genuine win
found was a modest DRY unification of the two activation blocks' `cacheAction` bodies
(claude.nix:454-461 `rm` vs. claude.nix:484-496 `mv`-to-`skills-disabled/`, including a
`DRY_RUN` asymmetry only `claudePruneRemovedSkills` has) — roughly 15 lines, not the "collision
handling + sweep generation + status semantics" bundle the handoff's prose promises.

**Q2 — the proposed per-entry `reason` field is a regression, not a mitigation.** The current
`leanExcludedMattpocockSkills` comment (claude.nix:218-225) states the rationale once, at the
group level ("signal/noise, not broken... grouped separately so the rationale... stays legible"),
and entries already carry per-entry inline comments today (claude.nix:227-233). A per-entry
`reason` field is not new capability; it demotes an existing, deliberately engineered group-level
invariant (at-a-glance scannability of "why this whole bucket is excluded") into scattered strings
a reader must re-cluster to recover the same understanding.

**Q3 — the proposed status vocabulary collides with a term CONTEXT.md already pins.**
CONTEXT.md's Agent-skills curation section defines **Parked skill** narrowly: "a skill
deliberately moved into a sibling `skills-disabled/` directory so no skill picker can discover
it" (CONTEXT.md:47-48). `claudeDisableGrillSkills` (claude.nix:484-496) does exactly this — its
`cacheAction` is `mv -- "$dir" "$disabled/$skill"` against `disabled="$parent/../skills-disabled"`
— it is CONTEXT.md's Parked skill by definition. The handoff's own worked example
(handoff-E, "The candidate" section) spells this status `disabled`, not `parked`: a direct
collision with a term CONTEXT.md already pins to a different, specific mechanism, offered with no
reconciliation. `removedSkillIds` maps cleanly onto CONTEXT.md's "removed from source filters"
language (CONTEXT.md:52). `lean` has no CONTEXT.md term at all — it is neither Parked nor part of
the Enabled-skill/Discovered-skill pair (CONTEXT.md:50-51). A four-way status enum cannot cleanly
absorb three distinct pinned concepts plus one unpinned one without either colliding (disabled vs.
parked) or requiring unbudgeted glossary work the handoff's three-step plan never accounts for.
Per Q3's own framing ("If statuses and CONTEXT.md terms can't be reconciled cleanly, that's a
signal the current lists already ARE the domain model"), that signal fired.

**Q4 — ordering with Handoff A affects scope, not the verdict.** Handoff A's appState module is
confirmed unimplemented (`rg -ni 'appstate|app-state|app_state'` across the worktree: zero hits).
Handoff A's own inventory explicitly claims `claudePruneRemovedSkills`, `claudeDisableGrillSkills`,
and the `mkSkillTargetRm`/`mkSessionSweep` helpers as inputs to its new module. Even granting that
Handoff A eventually removes the sweep-generation argument entirely, Q1–Q3 stand on their own
before and after Handoff A lands: the deletion test still fails, the vocabulary collision is still
unreconciled, and the group-comment regression is unrelated to sweep generation.

## What would change this decision

- If Handoff A's appState module lands and, as a side effect, produces a natural place for the
  ~15-line `cacheAction` DRY unification identified in Q1 — that narrow consolidation can be
  revisited on its own merits as part of Handoff A's landing, decoupled from a `skillPolicy` table.
- If a future proposal reuses CONTEXT.md's existing vocabulary exactly (`parked`, not `disabled`;
  a defined term for `lean`, or dropping `lean` from the table and leaving it a plain list) and
  drops the per-entry `reason` field in favor of preserving group-level rationale comments, Q2 and
  Q3 would need to be re-evaluated against the revised design.
- If `skills.explicit`'s transform closures gain a data-representable form (unlikely, since
  transforms are arbitrary Nix functions), Q1's "one consumer can't move into the table" objection
  would no longer apply to that consumer, though the deletion-test result for the other three lists
  would still need to be re-run.
- Absent one of the above, re-litigating this exact `skillPolicy` shape should link back to this
  ADR rather than re-opening the same three questions.

## References

- Handoff E: `/private/tmp/handoff-nix-config/handoff-E-skill-policy-table.md`
- `modules/home/claude.nix:172-241` (the four lists), `:454-461` and `:484-496` (the two
  activation/cacheAction sites), `:620-635` (`skills.explicit` consumers)
- `CONTEXT.md` Agent-skills curation section (Parked skill, Enabled skill vs. Discovered skill)
- Vendored collision check: `references/agent-skills-nix-master/lib/default.nix:121`
  (out of scope for this candidate)
