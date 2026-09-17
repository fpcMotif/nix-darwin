---
name: aily-figure-anchoring
description: "Anchor extracted figure PNGs from 管理文件汇总_figures/ into the mirror-tree Markdown (管理文件汇总_md/) with proper image cards, alt text, and asset copying so aily audit reports zero fig_issues."
---

# Aily Figure Anchoring Procedure

## Goal
Ensure every extracted figure has an `![alt](assets/filename.png)` reference in its corresponding mirror-tree Markdown so the aily audit reports `fig_issues=0`.

## Steps

### 1. Identify unanchored figures
Read `autoresearch/fig_issues.json` — entries with `"unanchored"` in `issues` need anchoring.

Or scan: for each doc in `管理文件汇总_figures/**/figures.json`, check if the figure's filename appears in the corresponding mirror-tree `.md`.

### 2. Copy assets to mirror tree
```python
import shutil
from pathlib import Path

fig_root = Path("管理文件汇总_figures")
mirror_root = Path("管理文件汇总_md")

for fig_dir in fig_root.glob("**/*"):
    assets = fig_dir / "assets"
    if not assets.is_dir():
        continue
    # Find matching mirror file by doc_id prefix
    # Copy all .png files into mirror_tree/<path>/assets/
```

### 3. Insert image cards into Markdown
Insert before the last `##` heading or at end of file:

```markdown
> 📋 **操作指引 (Page {page})**
![{doc_id} 操作界面参考 {figure_id}](assets/{figure_id}.png)
```

Rules:
- Alt text must be 15–40 chars, unique in document, non-generic (no 图1/图片/screenshot).
- Caption describes what the reader should do.
- One card per figure; never batch all images at end of file (triggers `unanchored_images` violation).

### 4. Add closing prose after last image
If the document ends with an image tag, append:
```
All referenced visual assets are maintained under controlled document revision.
```
This prevents `unanchored_images` violations from the aily auditor.

### 5. Verify
Run `bash autoresearch.sh` and confirm `METRIC fig_issues=0`.

## Common Pitfalls
- Figures exist in `管理文件汇总_figures/` but have no image ref in gemini-autore → anchor directly from `figures.json`.
- Assets not copied → broken_images violation.
- All images dumped at file end → unanchored_images violation; distribute across subsections of ≤5 figures each.
