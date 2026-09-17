---
name: feishu-docx-markdown-importer
description: Upload local Markdown documents and images into Feishu Cloud Docs and mount to Wiki Knowledge Spaces
---

# Feishu / Lark Cloud Docx & Wiki Importer

Procedure for uploading local Markdown documents (with local image assets, tables, and callouts) directly into Feishu / Lark Cloud Docs (`docx`) and mounting them into Wiki Knowledge Spaces.

## 1. Prerequisites & Auth
- Credentials: `FEISHU_APP_ID`, `FEISHU_APP_SECRET`.
- Required Scopes in Feishu Developer Console:
  - `docx:document` & `docx:document:create`
  - `drive:drive` & `drive:file:upload`
  - `wiki:wiki` & `wiki:space:retrieve`
- Version must be published in Feishu console for permissions to take effect.
- Token Endpoint: `POST https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal` with `{"app_id": ..., "app_secret": ...}`.

## 2. The 4-Step Ingestion Pipeline

### Step 1: Upload Raw Markdown to Drive
```http
POST https://open.feishu.cn/open-apis/drive/v1/files/upload_all
Authorization: Bearer <tenant_access_token>
Content-Type: multipart/form-data; boundary=----Boundary

file_name: document.md
parent_type: explorer
size: <len>
file: <markdown_bytes>
```
Returns `file_token: "boxcn..."`.

### Step 2: Trigger Native Import Task (md -> docx)
```http
POST https://open.feishu.cn/open-apis/drive/v1/import_tasks
Authorization: Bearer <tenant_access_token>
Content-Type: application/json

{
  "file_extension": "md",
  "file_token": "<file_token>",
  "type": "docx",
  "point": {
    "mount_type": 1,
    "mount_key": ""
  }
}
```
- Poll `GET https://open.feishu.cn/open-apis/drive/v1/import_tasks/:ticket` until `job_status == 0`.
- Yields `docx_token: "doxcn..."`.

### Step 3: Patch Image Blocks with Real Dimensions (Preserves 1:1 Aspect Ratio)
1. Fetch created blocks: `GET https://open.feishu.cn/open-apis/docx/v1/documents/:docx_token/blocks`.
2. Locate image blocks (`block_type: 27`).
3. For each local image in `assets/`:
   - Upload media: `POST /open-apis/drive/v1/medias/upload_all` with `parent_type: "docx_image"`, `parent_node: block_id`.
   - Returns `image_token: "boxcn..."`.
   - Read actual image dimensions (`width`, `height`) via Pillow.
   - Patch block: `PATCH /open-apis/docx/v1/documents/:docx_token/blocks/:block_id` with:
     ```json
     {
       "replace_image": {
         "token": "<image_token>",
         "width": 522,
         "height": 768,
         "align": 2
       }
     }
     ```

### Step 4: Move & Mount to Target Wiki Knowledge Space
```http
POST https://open.feishu.cn/open-apis/wiki/v2/spaces/:space_id/nodes/move_docs_to_wiki
Authorization: Bearer <tenant_access_token>
Content-Type: application/json

{
  "obj_type": "docx",
  "obj_token": "<docx_token>",
  "parent_wiki_token": "<parent_node_token>"
}
```
- If node is returned immediately, grab `node_token`.
- Otherwise poll task: `GET /open-apis/wiki/v2/tasks/:task_id?task_type=move`.
- Yields live Wiki URL: `https://<tenant>.feishu.cn/wiki/<node_token>`.
