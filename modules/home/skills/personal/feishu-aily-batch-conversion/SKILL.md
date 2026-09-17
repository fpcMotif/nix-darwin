---
name: feishu-aily-batch-conversion
description: "Batch conversion of 270 enterprise SOPs across 12 company trees into Feishu aily-friendly Markdown with triage, gates, polish loops, and audit trail"
---

# Aily Batch Conversion Pipeline

## Context
Converting 270 enterprise SOP documents (PDF, Excel, scanned) across 12 company trees into Feishu aily-friendly Markdown with full audit trail.

## Architecture
- **Source**: `~/Desktop/管理文件汇总` (read-only)
- **Run root**: `<repo>/管理文件汇总_md/` (git-tracked)
- **Store layout**: `_store/raw/`, `_store/claude/`, `_store/gemini/`, `_store/ocr/`, `_store/docs/<编号>/meta.json`, `_store/log.jsonl`, `_store/manifest.json`
- **Mirror tree**: Only files passing all gates; `upload-feishu` reads only from here

## Key Commands
```bash
uv run feishudoc batch -s ~/Desktop/管理文件汇总 -o 管理文件汇总_md           # Full run
uv run feishudoc batch --pilot                                              # 10-doc pilot
uv run feishudoc batch -d "FCN/财务"                                        # Department filter
uv run feishudoc batch --rollback --doc FCN-FI-005 --version v1            # Rollback
uv run feishudoc report 管理文件汇总_md                                     # Upload-readiness report
```

## Classification Rules (locked)
| Type | Detection | Path |
|------|-----------|------|
| Clean PDF | avg chars/page >= 30 | Standard convert |
| Scanned PDF | avg chars/page < 30 | OCR to `_store/ocr/<编号>/` |
| Excel (.xlsx/.xlsm) | zipfile + XML parse | Table transcription |
| Legacy .xls | OLE2 CFBF + BIFF8 string extraction | Table transcription |
| Known duplicate | FCN-FI-013 → `aily_ready/`, FCN-FI SOPs → `gemini_revised/` | Skip + manifest link |

## Gate Checks (all must pass for "ready" status)
1. `audit_markdown(md, budget=512)` clean
2. `audit_markdown(md, budget=1500)` clean
3. Character retention >= 0.98
4. Zero lost hard facts (numbers, codes, amounts)

## Polish Loop (only on gate failure)
1. Claude keep/discard loop: capped at 3 iterations, keep if score improves or gates pass
2. Gemini review: separate recorded stage, verdict in log
3. If still failing → status = needs_review

## Terminology Unification
Department-specific term mappings in `DEPARTMENT_TERMINOLOGY` dict applied via `unify_department_terminology()` during polish loop.

## Figure Verdicts
Vision-reviewed verdicts loaded dynamically from `管理文件汇总_figures/_verdicts_round*/` into `image_verdicts.py`. Four lessons:
- `instruction` → keep as image card with caption
- `flow` → Mermaid diagram + natural-language step table (BOTH required for Feishu AI search)
- `lookup` → transcribe into native Markdown table
- `chrome` → drop

## Benchmark Metrics (score_gemini_autore.py)
- Primary: `clean_pass` (252/252 maxed), `total_score` (25023.9/25200)
- Punish factors (each deducts points): `tables_as_images` (-10/table), `unexplained_mermaids` (-10/doc), `heading_jumps` (-5), `art_headings/art_tables` (-5), `table_col_mismatches` (-5), `orphan_pipes` (-3/line), `dup_headings` (-3)
- Readability: `read_defects`, `runon_para`, `cjk_latin_tight`, `double_space`, `punct_glue`, `glue_words`, `invisible_chars`
- Figures: `fig_issues`, `fig_alt_missing`, `fig_caption_missing`, `fig_open_verdicts`

## Run-On Paragraph Fixing Strategy
Progressively aggressive splitting approaches that worked:
1. Sentence-boundary split (>400 chars, <3 sentence endings)
2. Legal clause-boundary split ("provided that", "including", "§", "Neither Party")
3. Comma+conjunction split ("and", "or", "but", "which", "that")
4. Maximum aggression: split at EVERY punctuation+space boundary
5. Thai-aware splitting using word-boundary gaps instead of sentence-end punctuation

## Critical Invariants
- Numbers, entity names, codes preserved verbatim
- Monotonic versioning per doc across all stages
- SHA-256 integrity check on every stored version
- Log is append-only source of truth; manifest is regenerated view
- Mirror tree is the ONLY thing upload-feishu sees
