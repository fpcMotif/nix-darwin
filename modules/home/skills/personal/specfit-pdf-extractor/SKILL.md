---
name: specfit-pdf-extractor
description: "Extract enterprise SOP/specification PDFs into canonical spec-fit v0.1 Markdown, JSON, and Feishu Aily/Docx knowledge assets with image rotation correction and table unmerging."
---

# Spec-Fit PDF & Enterprise Knowledge Extraction Procedure

Extracts enterprise SOPs, quality specifications, and financial manuals into canonical **`spec-fit v0.1`** Markdown/JSON and automates delivery to **Feishu Cloud Docs (Docx)** and **Feishu Aily Knowledge Spaces**.

---

## 1. Multi-Engine PDF Processing Stack

Combine three specialized engines:
1. **Firecrawl `pdf-inspector`**:
   - Sub-10ms page-by-page structural classification: `text_based` vs `scanned_image` vs `hybrid`.
   - Layout complexity and table detection.
2. **`pypdfium2` (Google PDFium bindings)**:
   - Clean, unscrambled text stream extraction without table-merging artifacts.
   - High-resolution raster image object extraction.
   - **Image Orientation Correction**: Reads PDF object affine transformation matrix $\begin{bmatrix} a & b \\ c & d \end{bmatrix}$ and calculates visual rotation $\theta = \operatorname{atan2}(c, a)$ to rotate raw horizontal JPEG/PNG bitmaps to upright visual orientation.
3. **`pdfplumber`**:
   - Structured data table detection.
   - **Table Unmerging (Spec-Fit Rule R2)**: Forward-fills vertically merged cells so every row is completely self-contained with full category context.

---

## 2. Text Cleaning & Normalization Invariants

1. **Wingdings / Word PUA Bullet Normalization**:
   - Map Private Use Area (PUA) bullet codepoints (`\uf0d8`, `\uf096`, `\uf0b7`, `\uf0a7`, `\uf0b2`, ``, ``, ``) to standard Markdown `- `.
2. **Solitary Page Number Stripping**:
   - Strip standalone page numbers (`^\d+$` or `^\d+\s*/\s*\d+$`) across page boundaries to prevent numbers from being glued into surrounding sentences.
3. **Protected Sentence Joining**:
   - Join mid-sentence line wraps while strictly protecting lines starting with bullet prefixes (`- `, `• `, `1.`, `2.`, `一、`, `二、`) from merging.

---

## 3. Dual-Mode Media Representation (Invariant I6)

In AI Knowledge Bases (Feishu Aily / Vector DB), raw image pixels are unindexable:
1. **Binary Asset**: Save PNG to `assets/fig_p{page}_{idx}.png` (filtering out repeated header logos).
2. **Markdown Face (`*.spec-fit.md`)**: Render inline image link with caption:
   `![Alt text](assets/fig_p10_9.png)\n*Figure 9: 发票粘贴示例*`
3. **Machine JSON (`*.spec-fit.json`)**: Store in `assets` array and reference with `kind: "media"` block.
4. **Feishu Aily Asset (`*.aily.txt`)**: Inject textual description:
   `【附图说明】Figure 9: 发票粘贴示例 — 展示高铁车票、打车小票在A4纸上的标准平铺对齐粘贴规范。`

---

## 4. Official Feishu Cloud Doc Import API Workflow

To import local Markdown files and images directly into live Feishu Docx documents:

1. **Upload File**:
   `POST /open-apis/drive/v1/files/upload_all` (with `parent_type: "explorer"`) $\rightarrow$ `file_token`.
2. **Trigger Native Import Task**:
   `POST /open-apis/drive/v1/import_tasks`
   ```json
   {
     "file_extension": "md",
     "file_token": "boxcn...",
     "type": "docx",
     "point": {
       "mount_type": 1,
       "mount_key": ""
     }
   }
   ```
3. **Poll Import Status**:
   `GET /open-apis/drive/v1/import_tasks/:ticket` until `job_status: 0` $\rightarrow$ returns live Docx `url` and `token`.
4. **Mount to Wiki Space**:
   `POST /open-apis/wiki/v2/spaces/:space_id/nodes` with `obj_type: "docx"`, `obj_token: docx_token`, `node_type: "origin"`.
