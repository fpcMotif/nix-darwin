---
name: feishudoc-batch-aily-pipeline
description: "Orchestrate FeishuDoc batch conversion across document trees with multi-path triage, in-repo _store layout, deterministic gates, and upload-readiness reporting"
---

# FeishuDoc Batch Aily Conversion Pipeline

Repeatable procedure for running full-tree document conversions into Feishu aily-compliant Markdown with in-repo `_store` versioning, deterministic gates, flowchart dual-representation, and upload-readiness reporting.

## 1. Storage Architecture (In-Repo `_store` Layout)

```
<repo>/管理文件汇总_md/            ← run root, in-repo, git-tracked
├── <COMPANY>/<DEPT>/<DOC>.md       ← mirror tree: ONLY files passing all gates
└── _store/                         ← never uploaded to Feishu
    ├── raw/<编号>/v1.raw.md        ← stage 0: convert output, immutable
    ├── claude/<编号>/vN.md         ← stage 1: Claude keep/discard iterations
    ├── gemini/<编号>/vN.md         ← stage 2: Gemini-reviewed revisions
    ├── ocr/<编号>/                 ← ground-truth page bitmaps for scanned docs
    ├── docs/<编号>/meta.json       ← per-doc version lineage & SHA-256 index
    ├── log.jsonl                   ← append-only event log
    ├── manifest.json               ← run-level view regenerated from log + meta
    ├── PILOT_CALIBRATION_REPORT.md ← calibration report
    └── UPLOAD_READINESS_REPORT.md  ← upload-readiness report
```

## 2. Multi-Path File Triage

1. **Clean PDF**: Extract text and tables via SpecFit converter $\rightarrow$ evaluate 512/1500 gates $\rightarrow$ short-circuit if clean or enter polish loop.
2. **Scanned PDF**: Detected when text character density $<30$ chars/page $\rightarrow$ route to `_store/ocr/<编号>/` for bitmap ground truth $\rightarrow$ generate structured transcription.
3. **Excel Files (.xlsx, .xlsm, .xls)**: Parse sheets into standard Markdown tables with real header rows and non-empty columns.
4. **Known Duplicates**: Map directly to canonical outputs in `aily_ready/` or `gemini_revised/` with `skipped_duplicate` log event.

## 3. Visual & Flowchart Rules (Feishu AI Natural Language Compliance)

- **Flowcharts (`flow`)**: Must feature **pure natural language step-by-step descriptions** (`步骤`, `环节名称`, `责任岗位`, `触发条件与操作要求`, `下一步流转`) so Feishu AI natural-language semantic search indexes 100% of the workflow logic natively, with Mermaid diagrams placed below for human visual inspection.
- **Data Tables (`lookup`)**: Transcribe into native Markdown tables with valid header rows.
- **Instruction Screenshots (`instruction`)**: Keep as instructional image cards with operational captions (`> 📷 **操作指引：...**`) and descriptive alt text (15–40 chars, unique).
- **Chrome / Logos (`chrome`)**: Suppress/drop from document body.

## 4. CLI Execution Commands

```bash
# 1. Run 10-document pilot batch with calibration report
uv run feishudoc batch --pilot -s ~/Desktop/管理文件汇总 -o 管理文件汇总_md

# 2. Run specific department or tree batch
uv run feishudoc batch -s ~/Desktop/管理文件汇总 -o 管理文件汇总_md -d "FCN/财务"

# 3. View live manifest status summary
uv run feishudoc batch -o 管理文件汇总_md --status

# 4. Generate final upload-readiness and review report
uv run feishudoc report 管理文件汇总_md

# 5. Roll back a document in mirror tree to any prior stored version
uv run feishudoc batch --rollback --doc <DOC_ID> --version <vN>
```
