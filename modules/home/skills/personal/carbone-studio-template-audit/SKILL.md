---
name: carbone-studio-template-audit
description: "Audit, extract, and reconcile Carbone Studio template IDs, version hashes, and metadata with Feishu Bitable statement libraries."
---

# Carbone Studio & Feishu Bitable Template Reconciliation

Repeatable procedure for extracting, auditing, and reconciling Carbone Studio templates with Feishu Bitable statement libraries.

## 1. Carbone Studio Live Extraction Engine

Execute directly in Chrome DevTools Console (`https://<host>:<port>/#/templates`):

```javascript
(async () => {
  const token = localStorage.getItem("token") || sessionStorage.getItem("token") || "";
  const headers = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch("/templates", { headers });
  const raw = await res.json();
  const list = Array.isArray(raw) ? raw : (raw.data || raw.items || raw.templates || []);

  const report = list.map((t, i) => ({
    index: i + 1,
    title: t.name || t.title || t.filename,
    templateId: t.templateId || t.template_id || t.id || "MISSING",
    versionId: t.versionId || t.version_id || t.version || "N/A",
    category: t.category || "Statement",
    size: t.size ? `${(t.size / 1024).toFixed(2)} KB` : "N/A",
    status: (t.templateId || t.template_id || t.id) ? "PASS" : "FAIL"
  }));

  console.table(report);
  return report;
})();
```

## 2. Live Feishu Bitable OpenAPI Extraction

Fetch live statement records directly from Feishu Bitable without brittle UI scraping:

```python
import urllib.request, json

def fetch_feishu_bitable(app_id, app_secret, app_token, table_id):
    # 1. Tenant Access Token
    auth_url = "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal"
    auth_data = json.dumps({"app_id": app_id, "app_secret": app_secret}).encode("utf-8")
    req = urllib.request.Request(auth_url, data=auth_data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req) as resp:
        token = json.loads(resp.read().decode("utf-8")).get("tenant_access_token")

    # 2. Get Bitable Records
    url = f"https://open.feishu.cn/open-apis/bitable/v1/apps/{app_token}/tables/{table_id}/records?page_size=100"
    req2 = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req2) as resp:
        return json.loads(resp.read().decode("utf-8")).get("data", {}).get("items", [])
```

## 3. High-Precision Chinese-Aware Matching

When reconciling Feishu statement names with Carbone titles:
- Do NOT strip Chinese characters blindly: specific qualifiers (`鱼来源`, `含乳糖`, `大豆蛋白`, `氨糖`, `巴西`, `欧洲`, `美国`) distinguish variants sharing identical base English prefixes (e.g., `Allergen Statement`).
- Match regulatory numbers (`183-2005`, `852-2004`, `2023-915`, `396-2005`, `727-2022`) first to establish high-confidence anchors.

## 4. High-Resolution Visual Verification Card Generation

When generating cropped verification cards:
- Left Card: Contains `🔴 VERIFIED TEMPLATE NAME` with 5px red outline and 24pt bold typography.
- Right Card: Contains `🔴 EXTRACTED TEMPLATE ID` with 5px red outline and 32pt bold monospace font with generous padding to prevent digit clipping.
- Use TrueType fonts (`/System/Library/Fonts/Supplemental/Arial Bold.ttf` on macOS) for crisp rendering.
