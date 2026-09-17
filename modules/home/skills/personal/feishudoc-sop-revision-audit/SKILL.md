---
name: feishudoc-sop-revision-audit
description: "Procedure for revising and polishing enterprise SOPs for Feishu Doc and Aily import with Mermaid flowcharts, visual image classification, 6-dimension scorecard grading, and JSONL/JSON/CSV/HTML audit trails."
---

# Feishu Doc & Aily SOP Revision and Compliance Audit Procedure

## Overview
This skill codifies the end-to-end procedure for revising, polishing, and auditing enterprise Standard Operating Procedures (SOPs) and Markdown manuals for **Feishu Cloud Docs (Docx)** and **Feishu aily Knowledge Base import chunking**.

It enforces:
1. **Chunk Budget Ceiling ($\le 512$ tokens per leaf section)**: Prevents Aily mid-sentence hard-splitting.
2. **Distinct Heading Hierarchy (`#` $\to$ `##` $\to$ `###` $\to$ `####`)**: Eliminates chunk retrieval collision.
3. **Visual Ground Truth & Image Classification**:
   - Data lookup tables in images $\to$ transcribed into native Markdown tables.
   - Multi-step process flowcharts in images $\to$ synthesized into native Feishu Mermaid (`graph TD`) diagrams.
   - Software UI operation screenshots with bounding boxes/arrows (SAP, Kingdee, OA, Sinosure) $\to$ anchored under instruction steps with verified descriptive alt text.
   - Local relative file citations (`assets/{doc_id}/img_XX.png`) for local rendering in any markdown viewer.
4. **Zero-Fact-Loss Fidelity Guarantee**: 100% preservation of monetary amounts, tax IDs, SAP T-codes, dates, and account numbers.
5. **Multi-Format Audit Trail Generation**: Exports streaming `revisions.jsonl`, formatted `revisions.json`, spreadsheet `revisions.csv`, and an interactive visual dashboard `revision_audit_report.html` with SHA-256 cryptographic hashes.

---

## 6-Dimension Scorecard Calibration

Every document is graded across 6 dimensions ($100.0$ total points):
- **Structure** (20 pts): H1->H2->H3 hierarchy, distinct chunk paths, no collision
- **Token Budget** (20 pts): All sections $\le 512$ tokens, no run-on paragraphs
- **Lists** (15 pts): Native markdown lists (`1. `, `- `)
- **Tables** (15 pts): Header rows present, clean boundaries, separated label runs
- **Images** (15 pts): OCR/visual-grounded descriptive alt text, no generic/duplicate alts, non-trailing, local address cited
- **Fidelity** (15 pts): Zero lost hard facts, $\ge 98\%$ character retention

---

## CLI Commands

```bash
# 1. Batch revise SOPs into a new version with full JSONL, JSON, CSV, HTML, and co-located assets
uv run feishudoc revise gemini/raw \
  -o output/revised_sops \
  --jsonl output/revisions.jsonl \
  --json output/revisions.json \
  --html output/revision_audit_report.html \
  --csv output/revisions.csv \
  --assets-dir gemini/assets \
  --doc-version v2.0

# 2. Grade any document or directory against the 6-dimension Feishu Aily scorecard
uv run feishudoc audit output/revised_sops

# 3. Machine-readable JSON scorecard output for CI/CD checks
uv run feishudoc audit output/revised_sops --json

# 4. Dry-run revision audit check without writing to disk
uv run feishudoc revise gemini/raw --check
```
