---
name: macos-drafts-query-and-sync
description: "Query, extract, and non-blockingly sync notes from Agile Tortoise Drafts on macOS via read-only CoreData SQLite and URL schemes"
---

# macOS Drafts App Query, Extraction & Non-Blocking Sync

## Overview
Agile Tortoise Drafts on macOS stores notes and bookmarks in CoreData SQLite. Large Drafts libraries (80,000+ items) cause AppleScript and `@agiletortoise/drafts-mcp-server` bulk operations to time out (error -1712). Direct read-only SQLite queries provide sub-second access, and the macOS URL scheme provides non-blocking draft creation.

## The Golden Rule for Drafts Automation
Never let any single draft or merge output exceed **300 KB (or ~5,000 lines)**. If consolidating historical data:
- **Partition by period**: Split notes by quarter or month so each draft stays strictly under 300 KB.
- **Store master archives on disk**: Save comprehensive catalogs as standalone Markdown files under `~/Desktop/Drafts_Oversized_Catalogs/` on disk. Write back only concise digests with file or artifact pointers to Drafts.
- **Deduplicate and clean orphans**: Purge redundant single-URL capture duplicates and unprocessed orphaned changes before large merges to prevent CloudKit sync queue wedging.

## SQLite Database Path & Read-Only Connection
- **Path**: `~/Library/Group Containers/GTFQ98J4YG.com.agiletortoise.Drafts/DraftStore.sqlite`
- Always connect with URI read-only flag `?mode=ro` to avoid SQLite locking conflicts with the running Drafts app.

## CoreData Timestamp Handling
CoreData timestamps represent seconds since `2001-01-01 00:00:00 UTC` (offset `978307200` seconds from Unix epoch).
- Convert to Unix epoch: `(ZCREATED_AT + 978307200)`
- SQLite query date conversion: `datetime(ZMODIFIED_AT + 978307200, 'unixepoch')`
- Numerical date filtering: For a date like `2026-07-01`, calculate the integer threshold `(unix_timestamp - 978307200)` and compare directly against `ZMODIFIED_AT`.

## Folder Constants in `ZMANAGEDDRAFT`
- `ZFOLDER = 0`: Inbox
- `ZFOLDER = 1`: Flagged / Archive
- `ZFOLDER = 10000`: Trash (filter out with `ZFOLDER != 10000`)

## Filtering High-Signal Drafts
- **Exclude Link Dumps**: Filter out entries with $\ge 10$ URLs (`n_urls >= 10`) which are typically raw bookmark dumps or scrapers.
- **Extract User Annotations**: Strip URLs (`https?://[^\s]+`) and extract remaining text lines; entries with $\ge 20$ characters of non-URL text contain actual user commentary, architectural thoughts, or evaluation notes.

## Non-Blocking Draft Creation via macOS URL Scheme
Enforce the 300 KB ceiling before creating notes. If payload $\ge 300\text{ KB}$, write to `~/Desktop/Drafts_Oversized_Catalogs/` and create a pointer draft.
Avoid AppleScript `make new draft` when Drafts is busy or backgrounded. Dispatch directly via LaunchServices:
```python
import subprocess, urllib.parse

text = "# Title\nContent here"
encoded = urllib.parse.quote(text)
url = f"drafts://create?text={encoded}&tag=agent-summary"
subprocess.run(["open", url])
```
This executes in under 150ms without waiting for AppleEvent handshakes.
