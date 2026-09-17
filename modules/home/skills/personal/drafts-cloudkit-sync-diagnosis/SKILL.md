---
name: drafts-cloudkit-sync-diagnosis
description: Diagnose and resolve macOS Agile Tortoise Drafts CloudKit sync wedging caused by oversized records exceeding Apple 1MB CKRecord limit
---

# Drafts macOS CloudKit Sync Diagnosis & Repair

## When to Use
Use when Agile Tortoise Drafts on macOS fails to sync with other devices (Mac, iPhone, iPad), shows continuous background sync activity, or changes stall in `Changes.sqlite`.

## Background
Drafts on macOS synchronizes via Apple CloudKit using private zone `drafts`. CloudKit enforces a hard limit of **1,000,000 bytes (1 MB)** per individual `CKRecord` (including record fields and metadata). If any single note or version exceeds this limit (typically notes with $\ge 850\text{ KB}$ of raw text), CloudKit rejects the batch with `record too large`, causing an infinite retry loop that blocks all subsequent sync operations.

## The Golden Rule for Drafts Automation
Never let any single draft or merge output exceed **300 KB (or ~5,000 lines)**. If consolidating historical data into Drafts:
- **Partition by period**: Split notes by quarter or month so each note stays strictly under 300 KB.
- **Store master archives on disk**: Save large multi-megabyte catalogs as standalone Markdown files under `~/Desktop/Drafts_Oversized_Catalogs/` on disk. Write back only concise digests with file or artifact pointers to Drafts.
- **Deduplicate and clean orphans**: Purge redundant single-URL duplicates and unprocessed orphaned change records before large merges to prevent sync queue wedging.

## Diagnostic Workflow

### 1. Check Real-Time Sync Logs
Inspect the tail of the active sync log:
```bash
tail -n 60 ~/Library/Group\ Containers/GTFQ98J4YG.com.agiletortoise.Drafts/drafts-sync.log
```
Look for:
- `Insert Error Error saving record ... to server: record too large`
- `Updates Error Error saving record ... to server: record too large`
- `Insert Error Failed to modify some records`

### 2. Identify Wedged Records
Extract the failing record UUIDs from the log lines (e.g. `draft|--|<UUID>` or `draftVersion|--|<UUID>`).

### 3. Query Oversized Drafts & Versions
Always use `uv run python` to query SQLite with URI read-only flag `?mode=ro`:
```bash
uv run python -c "
import sqlite3, os
db_path = os.path.expanduser('~/Library/Group Containers/GTFQ98J4YG.com.agiletortoise.Drafts/DraftStore.sqlite')
conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
c = conn.cursor()
print('=== Drafts > 400KB ===')
c.execute('SELECT ZUUID, ZTITLE, length(ZCONTENT), ZFOLDER FROM ZMANAGEDDRAFT WHERE length(ZCONTENT) > 400000 ORDER BY length(ZCONTENT) DESC')
for r in c.fetchall():
    print(f'{r[0]}: {r[2]:,} bytes | folder={r[3]} | title={r[1][:40]}')
"
```

### 4. Check Pending Queue Backlog
Check how many changes are blocked in `Changes.sqlite`:
```bash
uv run python -c "
import sqlite3, os
path = os.path.expanduser('~/Library/Group Containers/GTFQ98J4YG.com.agiletortoise.Drafts/Changes.sqlite')
conn = sqlite3.connect(f'file:{path}?mode=ro', uri=True)
c = conn.cursor()
c.execute('SELECT ZPROCESSED, count(*) FROM ZMANAGEDCHANGE GROUP BY ZPROCESSED')
print(c.fetchall())
"
```

## Resolution Procedure
1. Export the content of any drafts $\ge 300\text{ KB}$ (or ~5,000 lines) to external `.md` files under `~/Desktop/Drafts_Oversized_Catalogs/`.
2. In Drafts.app or via JXA (`drafts-jxa-batch-ops`), split the note into smaller chunks ($\le 300\text{ KB}$ each) or move to Trash.
3. Permanently empty Drafts Trash so CloudKit does not attempt to sync an oversized tombstone record.
4. Verify the sync log drains:
   ```bash
   tail -f ~/Library/Group\ Containers/GTFQ98J4YG.com.agiletortoise.Drafts/drafts-sync.log
   ```
   Confirm `Sync Process Finished` and `Download Token Updated, Changes Saved`.
