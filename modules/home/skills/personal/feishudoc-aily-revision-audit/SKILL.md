---
name: feishudoc-aily-revision-audit
description: "Procedure for revising and auditing Markdown SOPs for Feishu Doc and Aily import with 6-dimension scorecard grading, native Mermaid flowcharts, and JSONL/HTML audit logs"
---

# FeishuDoc Aily SOP Revision & Audit Workflow

A repeatable procedure for revising raw or legacy Markdown SOPs into Feishu Doc & Aily import-ready formats with automated 6-dimension scorecard grading, Mermaid workflow diagram synthesis, visual image classification, and JSONL/JSON/HTML audit logging.

## Workflow Overview

1. **Audit & Grade Input Documents**:
   ```bash
   uv run feishudoc audit <input_dir> [--json] [--strict]
   ```
   Evaluates documents across 6 dimensions (0-100 score):
   - **Structure** (20 pts): H1->H2->H3 hierarchy, distinct chunk paths, no collision
   - **Token Budget** (20 pts): Leaf sections <= 512 tokens, no run-on prose (> 180 tokens)
   - **Lists** (15 pts): Native markdown lists (`1. `, `- `)
   - **Tables** (15 pts): Header rows present, clean column boundaries, separated label runs
   - **Images** (15 pts): Descriptive alt text, non-trailing, anchored beside instruction steps
   - **Fidelity** (15 pts): Zero lost hard facts, >= 98% character retention

2. **Visual Inspection & Image Classification**:
   - **Data Tables in Images**: Transcribe into native Markdown tables (e.g. Sanctioned Countries matrix, account lists).
   - **Process Flowcharts**: Convert multi-step visual flows into native Feishu Mermaid (`graph TD`) charts.
   - **Software UI Screenshots**: Retain as images, position directly next to instruction steps, and assign descriptive alt text (15-40 chars naming system + action).

3. **Execute Revision & Audit Generation**:
   ```bash
   uv run feishudoc revise <input_dir> \
     -o output/revised_sops \
     --jsonl output/revisions.jsonl \
     --json output/revisions.json \
     --html output/revision_audit_report.html \
     --assets-dir gemini/assets \
     --doc-version v2.0
   ```

4. **Verify Compliance & Audit Artifacts**:
   - Verify `output/revisions.jsonl` contains SHA-256 hashes (`input_sha256`, `output_sha256`), quantitative `diff_summary`, before/after scorecards, and explicit Aily revision reasons.
   - Open `output/revision_audit_report.html` for visual executive review.
