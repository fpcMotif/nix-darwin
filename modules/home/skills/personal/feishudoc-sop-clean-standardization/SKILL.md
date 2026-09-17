---
name: feishudoc-sop-clean-standardization
description: "Standardize enterprise SOPs, eliminate artificial regex malpractices, repair heading hierarchy, balance tables, localize overseas English metadata, generate canonical YAML frontmatter, and ensure Feishu Aily 512/1500 compliance with JSON/JSONL state tracking"
---

# FeishuDoc SOP Clean Standardization & Auto-Optimization Procedure

## Overview
This workflow standardizes enterprise management documents (SOPs, governance regulations, employee handbooks) for Feishu Cloud Docs and Aily RAG knowledge retrieval, completely eliminating historical regex malpractices while ensuring 100% compliance with token budgets and structural standards.

---

## 1. Core Principles & Anti-Malpractices

1. **Heading Naturalization & Collision-Free Hierarchy**:
   - **No Artificial Prefixes**: Strip `概述：`, `Notes：`, `Pt：`, `说明：` from all headings.
   - **No Artificial Suffixes**: Strip `·A`, `·B`, `·Página 12 de 19`, `·段`, `·分段`, `（分片）`, `（第N页）`, `（列N）`.
   - **Smooth Hierarchy (`H1` -> `H2` -> `H3`)**: Never jump from `#` directly to `###`, `####`, or `######`. Maintain monotonic level progression.
   - **Parent-Child Disambiguation**: When a sub-heading shares the same title as its parent (e.g. `行政专员 > 行政专员`), qualify the child as `行政专员 - 细则` or `行政专员 - Details`.
   - **Sibling Scope Unique Qualification**: When a generic title (e.g. `作用`, `选型`, `Criteria`) appears under multiple distinct parent sections, qualify with the parent section title (e.g. `进水电动阀 · 作用`, `反渗透系统 · 作用`).

2. **English & Overseas Subsidiary Localization**:
   - For all foreign subsidiary documents (`FUS`, `FBR`, `FDE`, `FCZ`, `FJP`, `FIN`, `FTH`, `FSA`, `FMY`, `FID`, `FGB`):
     - Localize document callout cards: `> 📋 **Document No.**：XXX ｜ **Version**：v1.0 ｜ **Effective Date**：... ｜ **Department**：... ｜ **Status**：Controlled`.
     - Translate administrative department names into standard English.
     - Scrub all injected Chinese boilerplate sentences (e.g. `本节说明...的要点与操作要求`).
     - Preserve authentic local language content (e.g. Japanese Kanji in `FJP` handbooks, original bilingual compensation schemes).

3. **Table Quality & Delimiter Enforcement**:
   - **Scrub Phantom Page Tables**: Drop 1~2 row tables that only contain extracted page markers (`Página X de Y`, `Page X of Y`) or empty cells.
   - **Standard Delimiter Rows**: Ensure every real table has a valid row 2 delimiter `| :--- | :--- |` matching the header column count.
   - **Table Row Balancing**: Short rows are padded with `-`, and oversized rows are cleanly merged to prevent column mismatches.
   - **No Fake Table Placeholders**: Strip fabricated filler words like `留空（列1）`, `稀有（列4）`, `地址续 1（列4）`, `填写栏`.

4. **Typography & Formatting Polish**:
   - **Pangu Spacing**: Ensure clean spacing between CJK glyphs and Latin/digits (`SOP 规范`, `2024 年`, `Net 30 Days`).
   - **Bold Tag Normalization**: Fix spaced asterisks (`* *` -> `**`), close unclosed note tags, and escape footnote asterisks (`Ending Time (*2)`).
   - **Double List Marker Normalization**: Fix nested list artifacts (`5. 1.` -> `5.1.`, `- - ` -> `- `).
   - **Trailing Whitespace Scrubbing**: Trim all line-end whitespace.

5. **Canonical YAML Frontmatter**:
   - Guarantee parseable, valid Spec-Fit YAML headers with `spec`, `title`, `lang`, `summary`, `source`, `tags`, and `metadata`.

---

## 2. State Tracking Architecture (JSON / JSONL)

Track all transformations and document lifecycles through structured files:
- `<run_root>/<doc_id>/current.md`: Final clean document.
- `<run_root>/<doc_id>/meta.json`: Per-document language, status, and applied fixes.
- `<run_root>/revisions.jsonl`: One-line JSON record per document across the entire corpus.
- `<run_root>/log.jsonl`: Event-by-event append log.
- `<run_root>/session.json`: Aggregate metric snapshot.
- `<run_root>/sample.json`: Complete document catalog.
- `_store/manifest.json`: Run-level ready status index.
- `docs/UPLOAD_READINESS_REPORT.md`: Publication readiness breakdown by company tree.

---

## 3. Deterministic Verification Gates

Run the automated test and score suite before delivery:
```bash
# 1. Benchmark scoring
bash autoresearch.sh

# 2. Pytest suite
uv run pytest
```
Verify:
- `clean_pass == total_docs` (100%)
- `dup_headings == 0`
- `heading_jumps == 0`
- `table_col_mismatches == 0`
- `orphan_pipes == 0`
