---
name: feishudoc-batch-aily-conversion
description: "Batch convert enterprise SOP document trees (PDF/xlsx/scanned) into Feishu aily-friendly Markdown mirror trees with in-repo _store layout, triage classification, deterministic gates, and calibration reporting. Use when bulk-converting document libraries for Feishu aily knowledge base import."
---

# Batch Aily Conversion Pipeline

## Overview
Converts an entire document tree (270+ files across 12 company trees) into aily-friendly Markdown using the `feishudoc batch` CLI with classification-driven routing, capped polish loops, and full audit trail.

## Key Commands

```bash
# Pilot batch (10 representative files) with calibration report
uv run feishudoc batch --pilot -s ~/Desktop/管理文件汇总 -o 管理文件汇总_md

# Department-ordered batch (e.g. FCN tree)
uv run feishudoc batch -s ~/Desktop/管理文件汇总 -o 管理文件汇总_md -d "FCN/财务"

# Full overseas trees
for tree in FMY FUS FBR FTH FJP FSA FIN FM FCZ FDE FGB; do
  uv run feishudoc batch -s ~/Desktop/管理文件汇总 -o 管理文件汇总_md -d "$tree"
  git add 管理文件汇总_md/ && git commit -m "feat(batch): $tree batch"
done

# Upload-readiness report (from log.jsonl + meta.json only)
uv run feishudoc report 管理文件汇总_md

# Rollback a document to any prior version
uv run feishudoc batch --rollback --doc FCN-FI-005 --version v1
```

## File Classification at Convert Time
| Type | Detection | Path |
|------|-----------|------|
| Clean PDF | text layer present (>30 chars/page avg) | Standard SpecFit convert |
| Scanned PDF | no text layer (<30 chars/page avg) | OCR ground-truth → `_store/ocr/` |
| Excel (.xlsx/.xlsm/.xls) | file extension | Stdlib table transcription |
| Known duplicate | doc_id in registry (aily_ready/, gemini_revised/) | Skip, link to canonical |

## In-Repo Storage Layout (locked)
```
管理文件汇总_md/
├── <TREE>/<dept>/<编号> <标题>.md   ← mirror: ONLY gate-passed files
└── _store/                           ← never uploaded
    ├── raw/<编号>/v1.raw.md         ← immutable Stage 0
    ├── claude/<编号>/v2.md          ← Claude keep/discard iterations
    ├── gemini/<编号>/vN.md          ← Gemini-reviewed revisions
    ├── ocr/<编号>/                   ← scanned page bitmaps
    ├── docs/<编号>/meta.json        ← per-doc index with SHA-256
    ├── log.jsonl                     ← append-only event log
    └── manifest.json                 ← REGENERATED from log+meta
```

## Deterministic Gates
Every file must pass ALL of:
1. `audit_markdown(text, budget=512).clean` — 512-token import budget
2. `audit_markdown(text, budget=1500).clean` — 1500-token cloud budget  
3. `fidelity_report(raw, polished)` retention ≥ 0.98
4. Zero lost hard facts (numbers, codes, amounts verbatim)

Files passing gates short-circuit to mirror. Failing files enter capped Claude polish loop (max_iterations), then Gemini review.

## Terminology Unification
Department-specific terminology maps ensure 术语一致性 within each domain:
```python
from feishudoc_extractor.batch import DEPARTMENT_TERMINOLOGY, unify_department_terminology
unified_text, applied = unify_department_terminology(md_text, department="FCN/采购")
```

## Figure Verdicts Integration
Vision-reviewed figure verdicts from `管理文件汇总_figures/_verdicts_round*` are auto-loaded:
- `instruction` → keep image card with operation caption
- `flow` → Mermaid diagram + natural-language step table
- `lookup` → native Markdown table transcription
- `chrome` → drop letterhead/logo

## Calibration Report
Generated per pilot run: `管理文件汇总_md/_store/PILOT_CALIBRATION_REPORT.md`
Contains: per-file cost, failure rates by classification, go/no-go recommendation.

## Quality Metrics to Track
- `clean_pass`: files passing all gates / total
- `read_defects`: OCR glue, run-on paragraphs, invisible chars (lower = better)
- `fig_issues`: unanchored figures, missing alt/captions (lower = better)
- `retention_min`: minimum character retention across corpus
- `double_space`, `punct_glue`, `cjk_latin_tight`: formatting defects (all should be 0)
