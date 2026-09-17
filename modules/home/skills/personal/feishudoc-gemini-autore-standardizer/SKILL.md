---
name: feishudoc-gemini-autore-standardizer
description: "Standardize enterprise SOPs, eliminate artificial regex malpractices, repair heading hierarchy, balance tables, localize overseas English headers, generate canonical YAML frontmatter, and ensure Feishu Aily 512/1500 compliance with JSON/JSONL state tracking"
---

# FeishuDoc Gemini-Autore SOP & Management Document Standardizer

Standardize enterprise SOPs, eliminate artificial regex malpractices, repair heading hierarchy, balance tables, localize overseas English metadata, generate canonical YAML frontmatter, and ensure Feishu Aily 512/1500 compliance with JSON/JSONL state tracking.

## When to Use
- Standardizing, repairing, or optimizing enterprise management documents (SOPs, employee handbooks, policies).
- Eliminating historical regex malpractices (`概述：`, `Notes：`, `·A`, `·Página`, `·段`, `（分片）`, `（第N页）`).
- Stripping artificial table placeholders (`留空（列1）`, `稀有（列4）`, `地址续 1（列4）`, `填写栏`).
- Localizing overseas subsidiary documents (FUS, FBR, FDE, FCZ, FJP, FIN, FTH, FSA, FMY, FID, FGB) into clean English/native metadata.
- Generating canonical Spec-Fit v0.1 YAML frontmatter and standard metadata callout cards (`> 📋 **Document No.**`).
- Aligning and balancing Markdown tables with valid delimiter rows (`| :--- | :--- |`) and zero broken columns.
- Auditing against Feishu Aily 512 (import) and 1500 (cloud) token chunk budgets with zero duplicate headings.

## Execution Procedure

### 1. Build and Normalize Documents
Run the canonical cleaner to remove artifacts, repair hierarchies, and apply typography formatting:
```bash
uv run python gemini-autore/build_gemini_autore.py
```

Core normalization rules applied:
1. **Heading Artifacts Removal**:
   - Strip prefixes: `概述：`, `Notes：`, `Pt：`, `说明：`, `简介：`.
   - Strip suffixes: `·Página X de Y`, `·A`, `·B`, `·段`, `·分段`, `（分片）`, `（第N页）`, `（列N）`.
   - Strip unclosed bold tags and spaced asterisks (`* *word**` -> `**word**`).
2. **Heading Level Normalization**:
   - Ensure strictly monotonic progression (H1 -> H2 -> H3 -> H4; clamp any jumps like H1 -> H3 or H1 -> H6).
   - Deduplicate parent-child identical titles (`行政专员 > 行政专员` -> `行政专员 > 行政专员 - 细则 / Details`).
   - Qualify sibling identical titles across sections with parent prefix to drive duplicate headings to 0.
3. **Overseas English Localization**:
   - For non-Chinese subsidiaries (FUS, FBR, FDE, FCZ, FIN, FTH, FSA, FMY, FID, FGB), translate metadata to English:
     `> 📋 **Document No.**：{id} ｜ **Version**：v1.0 ｜ **Effective Date**：{date} ｜ **Department**：{dept} ｜ **Status**：Controlled`
   - Strip injected Chinese boilerplate sentences (`本节说明...的要点与操作要求`).
4. **Table Structure & Delimiter Normalization**:
   - Scrub phantom 1~2 row page header/footer tables containing only page numbers or blank cells.
   - Ensure all tables carry a valid Markdown delimiter row: `| :--- | :--- |`.
   - Equalize column counts across all rows (pad missing cells with `-`).
5. **Canonical YAML Frontmatter**:
   - Generate valid YAML conforming to `spec-fit/0.1.0`.
   - Assign domain-specific 4-tag ontology by functional code (`-HR-`, `-FI-`, `-LG-`, `-PR-`, `-SD-`, `-PQ-`, `-TM-`, `-AM-`, `-IT-`).
6. **Typography & Entity Protection**:
   - Pangu spacing (space between CJK and Latin/numbers).
   - Protect email dot addresses (`User.Name@domain.com`).
   - Zero trailing whitespace on all lines.

### 2. Automated Quality Audit
Run the evaluation suite:
```bash
uv run python gemini-autore/score_gemini_autore.py
```
Outputs `METRIC clean_pass=252`, `METRIC aily_pass=252`, `METRIC dup_headings=0`, etc.

### 3. Synchronize to Mirror Tree and Manifest
Sync clean documents to `管理文件汇总_md/` and `_store/finalize/`, updating `manifest.json` and `UPLOAD_READINESS_REPORT.md`:
```bash
uv run python gemini-autore/sync_manifest_and_mirror.py
```

### 4. Hard Gate Verification
```bash
bash autoresearch.sh
bash autoresearch.checks.sh
uv run pytest
```
