---
name: pdf-grounded-figure-relocation
description: Relocate misplaced figure embeds inline to their true PDF sections using pdfium page-text matching; use when a markdown deliverable has figures clustered in appendices or far from their content and original PDFs are available for ground truth.
---

# PDF-Grounded Figure Placement Repair

Fixes figures dumped in end-of-file reference appendices by relocating them inline to the section whose content matches their source PDF page. Verified pattern from the feishudoc aily-batch loop (170+ relocations, zero metric regressions).

## Ground truth
- Original PDFs: `~/Desktop/管理文件汇总/<ORG>/<doc>.pdf`. The OCR markdown (`_store/raw/<ID>/v1.raw.md`) is a transcription, NOT pixel-verified — always double-check against the PDF when placement or fidelity is questioned.
- `fig-pNNN-MM` encodes source page NNN.
- Rasterize for visual checks: `pdfium.PdfDocument(pdf); page.render(scale=1.4).to_pil().save(...)`; then Read the PNG (image reading works).

## Checker (section-level verdict)
For each embed: extract page text via `page.get_textpage().get_text_bounded()`, normalize (`[^0-9a-z\u4e00-\u9fff]`→""), compare against each markdown section's normalized text (SequenceMatcher ratio, first ~1200/2000 chars). Flag as misplaced only when another section matches clearly better (>0.10 margin) and host sim < ~0.30. Line-context matching (immediate pre/post text) is too strict — it re-flags valid end-of-section placements and oscillates between passes.

## Relocator
Per flagged figure: delete the embed line, RECOMPUTE all heading offsets on the new body (stale offsets corrupt text mid-line), find target section (fuzzy title match: normalized equality or startswith), insert after the paragraph best matching the page text (paragraph regex must EXCLUDE table `|` and image `!` lines; fallback: section end). NEVER drop the embed on target miss — leave it in place.

## Guards (per doc)
- aily audit: no over_budget/empty_leaves/collisions/broken/generic/duplicate alts/runons/manual numbering/headerless/label runs.
- Score (retention + audit) drop ≤ 0.5, else revert the doc.
- If bare insert overflows a section (>512 tokens), retry wrapping the embed as its own uniquely-titled `####` subsection; fix heading level jumps (`#`*max(prev+1,1)) and dedupe heading texts afterwards.
- File must never end on an image line — append a closing prose sentence.
- For mirror/deliverable trees: verify embed URIs resolve (copy PNGs from the figures tree twin dir), and re-run the readability scanner (glue/double-space/invisible/run-on) before+after.

## Pitfalls learned (each caused a real bug)
1. `compiled_re.finditer(s, re.M)` passes re.M as a POSITION, not a flag — bake flags into `re.compile(..., re.M)`.
2. Grouping JSONL findings: one row per issue → `dict[key] = row` keeps only the last; group into lists.
3. Path keys: rglob under an absolute root yields absolute paths; report rows may store repo-relative — normalize both sides.
4. Moving embeds is char-neutral, but PRUNING appendix boilerplate is not: that text may coincide with raw chars and its removal costs retention. Prefer keeping prose + pointer line when a retention metric reads the same file.
5. Pure logo/letterhead fragments: skip entirely; cover pages with real content may stay in a slim cover appendix.

## Tooling reference (feishudoc repo)
`autoresearch/check_fig_placement.py` (checker), `autoresearch/relocate_figs.py` (relocator, `--keep-prose`), `autoresearch/mirror_fix.py` (deliverable-tree variant), `autoresearch/mirror_audit.jsonl` (findings format: one JSON per issue + summary line).
