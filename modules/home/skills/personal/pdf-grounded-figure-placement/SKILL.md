---
name: pdf-grounded-figure-placement
description: "Verify and repair figure placement in markdown SOP deliverables against original PDFs (pdfium page-text verdicts, inline relocation, broken-link repair) — use when figures sit in appendix dumps far from their content or embeds reference missing assets"
---

# PDF-Grounded Figure Placement Repair

Fixes figures embedded far from their content in markdown SOP deliverables by
verifying placement against the ORIGINAL PDFs, not the OCR transcription.

## Ground truth hierarchy
1. Original PDFs (here: `~/Desktop/管理文件汇总/<ORG>/<doc>.pdf`) — final word.
2. `fig-pNNN-MM` filenames encode source page NNN.
3. `_store/raw/<ID>/v1.raw.md` is OCR transcription — preserves order but is
   NOT pixel-verified; never trust it over the PDF.

## Verify placement (checker)
For every `![alt](...fig-pNNN-MM...)` embed: extract page NNN text with
pypdfium2 (`pdf[pno-1].get_textpage().get_text_bounded()`), normalize
(`[^0-9a-z一-鿿]+` → ""), and compare against the hosting section's text
(difflib ratio, page[:1200] vs section[:2000]). Flag only when another section
matches clearly better (>0.10 margin, best ≥0.25). Pages with <40 extractable
chars (pure screenshots) are unverifiable — skip. Line-context comparison
(pre/post neighbors) oscillates; use section-level verdicts.

## Relocate (fixer)
- Move embed AFTER the paragraph inside the target section whose normalized
  text best matches the page text (fallback: section end). Recompute heading
  offsets AFTER deleting the source line — stale offsets corrupt text.
- Never lose an embed: if the target title doesn't match, leave it in place.
- If the host section would exceed ~500 tokens, wrap the embed in its own
  uniquely-titled `####` subsection (title from alt text, dedup with counter).
- Delete appendix headings emptied by moves (title matches 附录/Reference
  Figures, body has no images/tables, ≤220 prose chars). Files must never end
  on an image line — append a short closing prose sentence if they would.
- Broken asset links: copy the PNG from the extraction tree
  (`管理文件汇总_figures/<same relative path>/<doc stem>/assets/`) beside the
  md. Embeds whose PNG exists nowhere are dead links — remove the line.
- Skip pure logo/letterhead fragments; cover pages with real content may stay
  in a slim `附录：封面与标识图` appendix.

## Guards (per file, before writing)
- Readability scanner count (glue/double-space/invisible/runon) must not increase.
- All embed URIs resolve beside the md after the edit.
- No heading level jumps, no duplicate headings.
- Score/audit regression >0.5 → revert that file, report the skip.

## Pitfalls learned
- `compiled_re.finditer(s, re.M)` passes re.M as a POSITION — bake flags into
  `re.compile(..., re.M)`.
- JSONL audits emit one row per issue: group rows per file before consuming,
  and normalize relative vs absolute path keys.
- Appendix prose can farm retention (chars coincidentally matching raw);
  removing it trades score for honest layout — document the trade.
- When subagents die mid-turn (model flakiness), fall back to deterministic
  scripted passes; they are reproducible and immune to turn kills.
