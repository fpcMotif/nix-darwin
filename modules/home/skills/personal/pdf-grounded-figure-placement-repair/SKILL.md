---
name: pdf-grounded-figure-placement-repair
description: "Verify and repair where embedded figures sit in Markdown deliverables against original PDFs (pdfium page-text matching, section-level verdicts, deterministic relocation with audit guards); triggers on figure placement audit, misplaced images, broken asset links, PDF-vs-markdown fidelity checks"
---

# PDF-Grounded Figure Placement Repair

Verifies and fixes where embedded figures sit in Markdown deliverables, using the ORIGINAL PDFs as ground truth. Developed in feishudoc (runs #162–#165); reusable for any doc tree with `fig-p<page>`-style extracted figures.

## Ground truth sources
- Original PDFs: `~/Desktop/管理文件汇总/<ORG>/<doc>.pdf` (user-provided location for feishudoc).
- `fig-pNNN-MM.png` encodes source page NNN.
- Rasterize for visual checks: `pypdfium2` → `page.render(scale=1.4).to_pil().save(...)`; read PNGs directly (vision works).
- OCR raw transcriptions preserve source ORDER but are NOT pixel-verified — prefer pdfium page text.

## Audit (mark-only mode when user says "don't change")
For each md with `![...](...fig...)` embeds:
1. Find the doc's PDF; extract page text: `pdf[page-1].get_textpage().get_text_bounded()`.
2. Host section = **narrowest** heading span containing the embed offset (outermost ancestor causes infinite re-flagging).
3. Section text for similarity must **strip image lines** (`![alt](uri)` alt/URI text dilutes ratios and causes ping-pong between passes).
4. Flag misplaced when another section matches the page text clearly better: `sim_host < 0.30 and best_s > sim_host + MARGIN` (0.20 flag / 0.30 act worked; below that = degenerate-structure noise).
5. Pages with <40 extractable chars (pure screenshots) are unverifiable — skip.
6. Write findings as JSONL (`{file, doc_id, fig, page, issue, host_section, suggested_section, sims}`) + summary line. Record-only = zero deliverable edits.

## Repair
1. **Broken links**: copy the PNG from the extraction tree (feishudoc: `管理文件汇总_figures/<same relative path>/<doc stem>/assets/`) beside the md.
2. **Dead links** (PNG exists nowhere): remove the embed line — it renders nothing.
3. **Misplaced**: move the embed line after the paragraph best matching the PDF page text (`difflib` on normalized text), inside the suggested section. Delete appendix headings the move emptied (only sections matching appendix-title patterns, no tables/images left, ≤220 prose chars).
4. **Over-budget fallback**: if the host section exceeds the chunk budget, wrap the embed in its own uniquely-titled subsection instead.

## Hard-won gotchas
- **Compiled regex**: `pattern.finditer(s, re.M)` passes `re.M` as a *position*, not a flag — bake flags into `re.compile(..., re.M)`.
- **Never lose embeds on target mismatch**: if the suggested section title doesn't match (fuzzy: normalized prefix/containment), leave the figure where it was.
- **Recompute offsets after each deletion** — stale spans corrupt text mid-line.
- **Alt/URI text pollutes sims**: always strip image lines before scoring sections, or moves ping-pong forever.
- **JSONL path keys**: rglob yields absolute or cwd-relative depending on root construction; normalize before dict lookups.
- **Per-file guards**: read-defect scanner count must not increase; every embed URI must resolve; file never ends on an image line; no heading level jumps or duplicate headings.
- **Oscillation floor**: if flagged count stops dropping across passes, the doc's heading structure is degenerate (repeated junk sections) — further moves are churn. Stop and record; fixing needs a heading-restructure decision.
- **Subagent flakiness**: when upstream models fail, workers die mid-turn ("exited without yield"). Fall back to deterministic scripted passes; they're reproducible and parallel-safe (single-doc verification modes).
