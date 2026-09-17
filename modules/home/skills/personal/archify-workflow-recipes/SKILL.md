---
name: archify-workflow-recipes
description: "Hard-won authoring recipe for Archify workflow diagrams: fixed-pitch grid constraints, label budgets, viewBox windows that pass showcase validation and 1440×900 containment on the first or second try. Use when authoring or repairing any Archify workflow candidate."
---

# Archify workflow authoring recipes

Empirical constraints from a 6-round showcase+containment loop. The validator's errors are terse; these are the decoded rules.

## Grid grain (the big one)
- Column pitch is FIXED and narrow: ~80px/col at viewBox width 720, scaling with `meta.viewBox[0]` (~pitch ≈ (vbW − ~160 margins) / 6).
- NEVER set explicit `width` on nodes. Default 92px is near the max that fits with ≥28px edge gaps. Width 136+ triggers lane-bounds overflow, sub-8px node gaps, micro-segments, and side-direction errors — all at once. Two widening rounds failed identically; don't retry the lever.
- Labels ≤ ~14 chars ("autosuggestions" at 102px FAILS vs 92px node). Sublabels ≤ ~12 chars at the 6px projected floor. Put everything else in `cards` and `groups`.
- Same-lane chain edges stay UNLABELED (gap < label mask). Move semantics into a group title or card; only delete a label when genuinely redundant, and say why.

## Topology that passes
- Main path zig-zags DOWN through lanes one row per column (like `examples/agent-tool-call.workflow.json`). A single horizontal 6-across rail in one lane fails: endpoint-side-direction + micro-segment errors from port spread.
- Vertical excursions: `fromSide:"bottom", toSide:"top", route:"drop"`. Upward return across rows: `fromSide:"top", toSide:"bottom"` (no route). Left sweep: `route:"return-left"` with `left/left` sides — `outside-left` is NOT in the workflow route enum.
- Put intermediate lanes' nodes at DIFFERENT columns than the drop column, or the drop crosses an unrelated node (`clean-flow/edge-through-node`).
- Drop a low-value edge before adding any routing control (a "skipped when absent" dashed edge cost a crossing and two label collisions).

## ViewBox window (desktop-first containment)
- Portrait viewBox × 1440px reader = ~1800px-tall SVG → `visual-check` fails overflowY everywhere. The viewer reserves a ~410px side rail at 1440 (diagram gets ~930px), and cards render BELOW the SVG when the rail is narrow.
- Legend needs `viewBox[1] >= 714` (fixed, independent of entry count).
- Desktop-readability floor: projected node text ≥ 6px at 1440 ⇒ `scale = 930 / vbW ≥ 0.75` ⇒ **vbW ≤ 1240**.
- Working window: **`viewBox: [1200, 714]`** → scale 0.775, svg ≈553px tall. Total flow must stay ≤900: keep to ONE card (~4 items) if the two-card layout overflows; cut any card that restates node sublabels.

## Repair loop discipline
- One diagnosed geometry control per round (`labelAt` from the suggested fix works verbatim).
- Track best error count; stop after two rounds without improvement on the current lever, switch levers (width → labels → viewBox → card count), and never edit a candidate after a passing `deliver`.
- `visual-check` receipt `visualReview: "pending"` always — read the PNGs yourself before claiming polish. Legend defaults show generic component-type names; override with `meta.legend.entries.<kind>.label` when they mislabel the domain (pure win, no geometry impact).
