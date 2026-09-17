---
name: feishudoc-aily-sop-revision-audit
description: "Revise and polish Markdown SOPs for Feishu Doc & Aily import chunking with Mermaid diagrams, fact fidelity checks, and JSONL/HTML audit trails."
---

# Feishu Doc & Aily SOP Revision & Multi-Format Audit Procedure

## Overview
When revising enterprise SOP Markdown documents for Feishu Docx and Feishu Aily RAG knowledge spaces:
1. **6-Dimension Scorecard Compliance (0–100 pts)**:
   - **Structure (20 pts)**: Strict `#` -> `##` -> `###` -> `####` hierarchy. Every leaf section has a distinct heading path to prevent Aily search chunk collisions.
   - **Token Budget (20 pts)**: All leaf sections must stay $\le 512$ tokens (`CHUNK_BUDGET`) to prevent mid-sentence hard chunking during vector indexing. Paragraphs running past 180 tokens are split at sentence boundaries (`。`, `；`).
   - **Lists (15 pts)**: Standardize hand-typed Chinese numbering (`1、`, `1.1、`, `①`, `(1)`) into native Markdown lists (`1. `, `- `).
   - **Tables (15 pts)**: Every table must have a valid header row. Fix broken/empty grid rows and separate collapsed label runs (`名称：...地址：...`).
   - **Images (15 pts)**: Inspect image assets visually. Eliminate generic alt texts (`![图示](...)`), duplicate alt texts, and trailing image clusters at the end of files. Cite local relative paths on current machine (`assets/{doc_id}/img_XX.png`).
   - **Fidelity (15 pts)**: Zero lost hard facts (amounts, dates, tax IDs, SAP transaction codes, account numbers). Character retention $\ge 98\%$.

2. **Visual Image Classification & Handling**:
   - **Pure Data Lookup Tables**: Transcribe into native Markdown tables (e.g. Sanctioned Countries / Regions Matrix, Bank Accounts directory).
   - **Multi-Step Flowcharts**: Convert into native Feishu Mermaid (`graph TD`) diagrams.
   - **Software UI Screenshots (SAP/Kingdee/OA/Sinosure)**: Keep as images with red instructional arrows intact, anchored directly under the corresponding instruction step with descriptive alt text (`![System Action Description](assets/...)`).

3. **Multi-Format Audit Logging**:
   - Emit streaming **`revisions.jsonl`** recording: `document_id`, `input_sha256`, `output_sha256`, `scorecard_before` vs `scorecard_after`, `diff_summary` (lines, tokens, headings, diagrams), exact `revisions` list, and detailed `revision_reasons`.
   - Emit **`revisions.json`**, **`revisions.csv`**, and interactive **`revision_audit_report.html`** with real-time search filtering and 6-dimension badge bars.

## CLI Execution Recipe

```bash
# 1. Revise all SOPs in a directory with full audit trails and asset co-location
uv run feishudoc revise <input_dir> \
  -o <output_dir> \
  --jsonl <output_dir>/revisions.jsonl \
  --json <output_dir>/revisions.json \
  --html <output_dir>/revision_audit_report.html \
  --csv <output_dir>/revisions.csv \
  --assets-dir <assets_dir> \
  --doc-version v2.0

# 2. Grade any existing document or directory against the 6-dimension scorecard
uv run feishudoc audit <target_dir>

# 3. Machine-readable JSON output for CI/CD pipelines
uv run feishudoc audit <target_dir> --json

# 4. Dry-run simulation check
uv run feishudoc revise <input_dir> --check
```
