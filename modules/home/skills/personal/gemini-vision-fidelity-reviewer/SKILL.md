---
name: gemini-vision-fidelity-reviewer
description: Cross-model visual fidelity reviewer using Gemini Vision (Gemini 3.7 Flash) to compare PDF page images against converted Markdown for Feishu Aily SOP documents with figure semantic placement and disagreement reporting.
---

# Gemini Vision Fidelity Reviewer

Procedures for running cross-model visual fidelity audits comparing source PDF pages (1800px hi-res renders) against converted Markdown for Feishu Aily SOP documents.

## Architecture & Separation of Concerns
- `gemini_vision_reviewer.py`: Dedicated fidelity auditor. Compares PDF renders vs. Markdown and emits canonical verdicts (`work/recheck/<doc>.rN.json`).
- `gemini_backend.py`: Unified backend interface supporting `EvalCompletionBackend` (for kernel `completion()`), `GeminiCliBackend` (for CLI), and `StubVisionBackend` (for offline tests).
- `report_disagreements.py`: Compares text reviewer verdicts vs vision reviewer verdicts to detect `vision_caught_defect` vs `vision_cleared_hallucination`.

## Feishu Aily RAG House Conventions
- **Allowed adaptations (Do NOT flag as defects)**:
  - Unnumbered headings (source numbering converted into Markdown `#`, `##`, `###` hierarchy).
  - 1-sentence topic lead-in right below headings.
  - Paragraphs split into bullet points to satisfy the 180-token / 512-token budget.
  - Preserving source typos / oddities (source fidelity outranks grammar correction).
- **Real defects (Must flag)**:
  - Dropped policy clauses, table rows, or values.
  - Altered facts, numbers, amounts, currencies, or dates.
  - Language mutation (replacing Chinese terms with English or vice versa).
  - Structural mutilation (headings inserted mid-sentence or splitting numbered lists).
  - Misplaced figures.

## CLI & Programmatic Usage
```python
from pathlib import Path
from autoresearch.figure_pass.gemini_backend import EvalCompletionBackend
from autoresearch.figure_pass.gemini_vision_reviewer import ReviewConfig, review_doc

backend = EvalCompletionBackend(completion_fn=completion, model="default")
config = ReviewConfig(work_dir=Path("autoresearch/figure_pass/work"), model="gemini-3.7-flash")
verdict = review_doc("FMY-FI-001", backend=backend, config=config)
```

```bash
# Run CLI review
uv run python autoresearch/figure_pass/gemini_vision_reviewer.py <DOC_ID> --model gemini-3.7-flash

# Run cross-model disagreement analysis
uv run python autoresearch/figure_pass/report_disagreements.py --work autoresearch/figure_pass/work
```
