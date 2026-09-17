---
name: feishudoc-figure-semantics-describer
description: "Converts Feishu SOP figures (UI screenshots, process flowcharts, forms) into rich, blind-guide procedural prose and generates interactive all-in-one visual inspection galleries for Feishu Aily RAG knowledge bases."
---

# FeishuDoc Figure Semantics Describer

Converts Feishu SOP figures (UI screenshots, process flowcharts, forms) into rich, blind-guide procedural prose and generates interactive all-in-one visual inspection galleries for Feishu Aily RAG knowledge bases.

## The 3-Tier Image Packaging Architecture
1. **Layer 1: Context Anchor (Lead-in)**: 1 sentence on the line immediately before the image.
2. **Layer 2: Accessibility Tag (Alt Text)**: 15–40 chars inside `![alt](...)` for screen readers.
3. **Layer 3: RAG Core Carrier (Blind-Guide Prose)**: Detailed step-by-step numbered steps (`1. `, `2. `) naming printed buttons, input fields, dropdowns, and observable feedback. (Feishu Aily AI indexes only standard body text; it cannot read pixels, code blocks, or Whiteboards).

## Modules
- `figure_describer.py`: Generates blind-guide procedures and emits proposals to `<work>/figdesc/<doc_id>.json`.
- `mermaid_validator.py`: Pure validator for GitHub-compatible Mermaid blocks (rejects `click`/`href`, `%%{init}%%`, raw HTML, unquoted punctuation).
- `token_estimator.py`: CJK-aware token estimator ($1\text{ CJK char} \approx 1\text{ token}$, $3.2\text{ Latin chars} \approx 1\text{ token}$).

## Usage
```python
from pathlib import Path
from autoresearch.figure_pass.gemini_backend import EvalCompletionBackend
from autoresearch.figure_pass.figure_describer import FigDescConfig, describe_doc_figures

backend = EvalCompletionBackend(completion_fn=completion, model="default")
config = FigDescConfig(work_dir=Path("autoresearch/figure_pass/work"), model="gemini-3.7-flash")
proposals = describe_doc_figures("FCN-FI-003", backend=backend, config=config)
```

```bash
# Run CLI describer
uv run python autoresearch/figure_pass/figure_describer.py <DOC_ID> --apply --model gemini-3.7-flash
```
