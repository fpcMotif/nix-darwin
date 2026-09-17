---
name: feishudoc-fig-placement-repair
description: "Verify and repair figure placement in feishudoc scored docs and mirror deliverable against original Desktop PDFs (pdfium page-text matching, relocation with no-loss guards)"
---

# PDF-grounded figure placement repair (feishudoc)

Procedure for verifying and fixing figure placement in `gemini-autore/**/current.md` (scored) and `管理文件汇总_md/**` (mirror deliverable), using the ORIGINAL PDFs as ground truth.

## Ground truth
- Original PDFs: `~/Desktop/管理文件汇总/<ORG>/<doc>.pdf` (user-provided location; NOT in repo).
- `管理文件汇总_md/_store/raw/<ID>/v1.raw.md` is the OCR transcription in source order (images inline) — usable as a proxy, but NOT pixel-verified.
- Extracted figure PNGs: `管理文件汇总_figures/<ORG>/.../<doc>/assets/fig-pNNN-MM.png`; metadata in `管理文件汇总_figures/figures_report.json` (alt/caption/lesson/page). `fig-pNNN-MM` encodes source page NNN.
- Rasterize pages for visual checks: `pypdfium2` render → PNG → read image.

## Tooling (committed in repo, autoresearch/)
- `check_fig_placement.py` — scored-doc verdicts: pdfium page text vs hosting section; host = NARROWEST containing section; section text EXCLUDES image lines; flag only when another section matches clearly better (+0.20 ratio margin).
- `audit_mirror.py` — same verdicts for the mirror tree → `mirror_audit.jsonl`.
- `relocate_figs.py` — moves flagged embeds inline after the paragraph best matching the PDF page text; per-doc guards (audit clean, score drop ≤0.5, embed count never decreases).
- `mirror_fix.py` — mirror variant: broken-link repair (copy PNGs from figures tree), relocation, dead-link removal; no-loss invariant (per-file embed count can never decrease).

## Hard-won invariants (each was a multi-session bug)
1. **Parent shadowing**: fuzzy section lookup must prefer EXACT normalized-title match, then LONGEST prefix — `t2.startswith(t1)` lets a short parent heading shadow its own child, so figures land in parents and audits re-flag them forever. (Implemented as `find_section()` in relocate_figs.py.)
2. **Strip embed lines from section text** before similarity scoring: alt/URI characters dilute matches and cause placement ping-pong between sibling sections.
3. **Narrowest-containing-section host detection**: first-match-in-document-order picks the outermost ancestor and mis-attributes leaf-correct placements.
4. **Audit counter artifact**: an audit that skips files without a matching PDF makes `embeds_scanned` wobble between runs — compare fig-token multisets (`git show <ref>:<file>` vs worktree, with `git -c core.quotepath=off`) before believing any "lost embeds" claim.
5. **No-loss invariant**: any repair pass must never reduce a file's embed count; revert on violation. Deduplication of stray duplicates is the only legitimate count reducer.
6. **Never chase retention by degrading docs**: restoring generic alt text (`图示：…`) costs −2 pts/occurrence vs +0.1 retention gain; duplicated OCR cells and curated frontmatter stay untouched.

## Verification gates
- Scored docs: `uv run python gemini-autore/score_gemini_autore.py --doc-id <ID> --json` (clean_pass=1, aily_pass=1) + `score_breakdown.py --doc-id <ID>` (all deduction buckets 0) + placement checker flagged count 0.
- Mirror: `audit_mirror.py` counts + full `bash autoresearch.sh` (read_defects=0, fig_issues=0).
- Subagents are unreliable when upstream models flap (workers die mid-turn); deterministic scripted passes with per-doc revert guards are the fallback. Parked peers must NOT be messaged — messaging revives them mid-orchestrator-work and causes out-of-scope edits.
