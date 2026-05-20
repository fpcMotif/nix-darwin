# Karpathy "Observable signals" — proposed footer addition

**Status:** hypothetical plan. Not applied. Apply once `modules/home/claude.nix` is out of its current merge-conflict state and the Karpathy footer bindings (`appendKarpathy`, `grillKarpathyFooter`, `deepenKarpathyFooter`) are present in the `let` block.

## Why

The two existing Karpathy-alignment footers stop at prescription (*what* to do). Karpathy's own README closes every principle on a one-line falsifiable check, and ends with a "how to know it's working" section. That close is what these footers under-emphasise. Adding **Observable signals** turns each footer from advice into a self-testing ritual — *Goal-Driven Execution applied to the skill itself*.

This is polish on existing integration, not new integration. The footers already encode:

- `grillKarpathyFooter` → **Think Before Coding** + Goal-Driven capstone (`Close with verifiable goals`).
- `deepenKarpathyFooter` → **Simplicity First** (seam rule) + **Surgical Changes** (propose vs execute) + Goal-Driven capstone.

What's missing is the closing falsifiable signal — *added below*.

## Change 1 — `grillKarpathyFooter`

Append before the closing `'';` (after the line ending `"make it work" forces it back to ask.`):

```markdown

## Observable signals

You'll know this skill is working when:
- The user changes their mind mid-grilling — the questions found something they hadn't articulated.
- CONTEXT.md terms surface unchanged in later sessions; the vocabulary stuck.
- Implementation plans downstream contain fewer wrong assumptions that need walking back.
```

## Change 2 — `deepenKarpathyFooter`

Append before the closing `'';` (after the closing ` ``` ` of the verify-loop block):

```markdown

## Observable signals

You'll know this skill is working when:
- Every proposed candidate passes the deletion test — removing it makes the codebase clearly worse.
- No proposed seam ships with only one adapter; the second adapter earned it.
- Tests at the deepened interface survive subsequent internal refactors (they describe behaviour, not implementation).
```

## Verify

```
1. darwin-rebuild build --flake .#<host>     -> verify: build succeeds (string-only additions, no semantic Nix changes)
2. cat $(readlink ~/.claude/skills/grill-with-docs/SKILL.md) | grep -A4 'Observable signals'
                                              -> verify: signals section present in the rendered skill
3. cat $(readlink ~/.claude/skills/improve-codebase-architecture/SKILL.md) | grep -A4 'Observable signals'
                                              -> verify: signals section present in the rendered skill
```

## Rollback

```
git restore modules/home/claude.nix
```

No other files touched by this change.

## Out of scope (mentioned only so it's tracked, not part of this plan)

The following are *stylistic* refinements I proposed earlier — Karpathy-register tightening — and are deliberately **not** included here. Adopt separately if desired:

- Rewrite the `grillKarpathyFooter` "two reinforcements" as a negation triplet: *"Don't collapse to one interpretation silently. Don't paper over contradictions. Don't hide your own confusion — it's data."*
- Compress the `deepenKarpathyFooter` propose-vs-execute paragraph into a one-line test: *"The test: during proposal, suggest anything; during execution, every changed line traces to the approved candidate."*

These don't close the observable-signals gap and would violate principle 3 (Surgical Changes) if bundled into the same change.

## Karpathy-principle audit of *this* plan

- **Think Before Coding** — the gap is named (no observable signals), the alternative (do nothing; the footers are "mostly there") is acknowledged.
- **Simplicity First** — two appended blocks, no new helpers, no refactors.
- **Surgical Changes** — only the two `''`-quoted footer bodies; nothing else in `claude.nix` moves.
- **Goal-Driven Execution** — verify step is explicit and falsifiable (grep for the section in the rendered SKILL.md).
