---
name: drafts-batch-classification-and-tagging
description: "Procedure for classifying, tagging, and triaging incoming and historical drafts in Agile Tortoise Drafts on macOS using JXA batch ops and word-boundary semantic rules"
---

# Drafts.app Batch Classification, Tagging & TCC Guardrails

Repeatable procedure for classifying, tagging, and triaging incoming and historical drafts in Agile Tortoise Drafts on macOS without locking the app, hitting AppleScript `-1743` (TCC) errors, or exceeding CloudKit sync thresholds.

## Core Architecture & Invariants

1. **The Golden Rule for Drafts Automation**:
   - Never let any single draft or merge output exceed **300 KB (or ~5,000 lines)**.
   - Master catalogs and large multi-megabyte text dumps must be offloaded to disk under `~/Desktop/Drafts_Oversized_Catalogs/`.
   - Write back only concise digests with artifact pointers to Drafts.
   - **Explicit User Reconfirmation Required**: Always obtain explicit user confirmation before any Drafts mutation: tag, archive, trash, content replacement, empty-trash, or write-back. Present exact counts, folder scope, destination, and manifest path first.

2. **AppleScript vs JXA Scripting Dictionary**:
   - Drafts sdef defines:
     - `d.tagList()` (getter: array of strings)
     - `d.tagList = ["tag1", "tag2"]` (setter: accepts array of strings)
     - `d.folder = "inbox" | "archive" | "trash"`
   - Setting `d.tagList` directly via JXA automatically handles CoreData's internal `ZZZ` delimiter encoding (`ZZZtag1ZZZ ZZZtag2ZZZ`) in `ZCACHED_TAGS`.

3. **TCC Permission Handling (`-1743`)**:
   - Direct `Application("Safari")` or `Application("Google Chrome")` tab manipulation via `osascript` in background shells triggers `-1743` (`errAEEventNotPermitted`) on modern macOS.
   - For opening URLs without TCC prompts, use LaunchServices via `open -a Safari <url>` or Cocoa's `$.NSWorkspace.sharedWorkspace.openURL(...)`.

---

## Batch Classification Procedure

### 1. Identify Target Drafts via Read-Only SQLite
Always query with `?mode=ro` against a copy or directly without writing:

```python
import sqlite3, os, datetime

db_path = os.path.expanduser("~/Library/Group Containers/GTFQ98J4YG.com.agiletortoise.Drafts/DraftStore.sqlite")
conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
c = conn.cursor()
COREDATA_EPOCH = 978307200
since_coredata = datetime.datetime(2026, 9, 7, tzinfo=datetime.timezone.utc).timestamp() - COREDATA_EPOCH

# Incoming only: created since last catalog (CoreData epoch = Unix - 978307200).
# Do not classify the batch you just restored from trash.
c.execute("""
    SELECT ZUUID, ZCREATED_AT, ZCONTENT, ZCACHED_TAGS
    FROM ZMANAGEDDRAFT
    WHERE ZFOLDER = 0
      AND ZCREATED_AT >= ?
    ORDER BY ZCREATED_AT DESC
""", (since_coredata,))
rows = c.fetchall()
```

### 2. Semantic Tagging Rules (Word-Boundary Enforced)
Avoid naive substring matches like `"ui"` matching `"building"`. Always use compiled word-boundary regexes:

```python
import re

# Never add "build" / "building" here. That tagged deepmindsafetyresearch.medium.com/...building-safe... as frontend.
re_frontend = re.compile(r'\b(css|react|swift|swiftui|frontend|ui|tailwind|webgl|three\.js|figma|layout|flexbox|appkit|canvas|svg)\b', re.I)
re_agents = re.compile(r'\b(agent|agents|subagent|claude code|codex|pi coding agent|harness|opencode|multi-agent|agentic|worktree)\b', re.I)
re_mcp = re.compile(r'\b(mcp|model context protocol|webmcp)\b', re.I)
re_ai = re.compile(r'\b(ai|llm|llms|transformer|transformers|prompt|evals|reasoning|deepmind|openai|anthropic|machine learning|cot)\b', re.I)
re_math = re.compile(r'\b(math|linear algebra|category theory|quiver|topology|theorem|proof|lean|algebraic|lemma|navier-stokes)\b', re.I)
re_systems = re.compile(r'\b(database|databases|postgres|distributed|consensus|raft|paxos|linux|kernel|network|wireguard|tailscale|cloud)\b', re.I)
re_safety = re.compile(r'\b(safety|alignment|eval|evals|security|jailbreak|red teaming|aisi)\b', re.I)
re_econ = re.compile(r'\b(economics|degrowth|history|policy|sociology|political|pension|capital|china)\b', re.I)
```

Map source URLs:
- `arxiv.org` → `["arxiv", "math-research"]`
- `github.com` / `gist.github.com` → `["github"]`
- `x.com` / `twitter.com` → `["twitter"]`
- `youtube.com` / `youtu.be` → `["youtube"]`
- `docs.google.com` → `["docs"]`
- General URLs → `["reading"]`
- Text-only drafts → `["notes"]`

### 3. Apply Tags via JXA Batch Script

Save payload to `/tmp/apply_tags.json` as `[{"id": "<UUID>", "tags": ["tag1", "tag2"]}]` and execute:

```javascript
ObjC.import("Foundation");
const path = "/tmp/apply_tags.json";
const content = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null).js;
const items = JSON.parse(content);
const app = Application("Drafts");

for (let i = 0; i < items.length; i++) {
  try {
    const d = app.drafts.byId(items[i].id);
    if (d) {
      d.tagList = items[i].tags;
    }
  } catch (e) {}
}
```

### 4. Verification & Sync Check
Confirm in `DraftStore.sqlite`:
```sql
SELECT ZCACHED_TAGS, count(*) FROM ZMANAGEDDRAFT WHERE ZFOLDER = 0 GROUP BY ZCACHED_TAGS;
```
Check `~/Library/Group Containers/GTFQ98J4YG.com.agiletortoise.Drafts/drafts-sync.log` to confirm `Updates Complete` and `No Pending Inserts`.
