---
name: drafts-jxa-batch-ops
description: High-throughput batch manipulation of Drafts.app on macOS using JXA (JavaScript for Automation) and zero-lock SQLite snapshots
---

# High-Throughput Drafts.app Batch Operations via JXA

Use this procedure when querying, classifying, or batch-mutating large volumes (hundreds or tens of thousands) of notes in Agile Tortoise Drafts on macOS without locking the app or hitting AppleScript recursion crashes.

## The Golden Rule for Drafts Automation

Never let any single draft or merge output exceed **300 KB (or ~5,000 lines)**. If consolidating historical data:
- **Partition by period**: Split notes by quarter or month so each draft stays strictly under 300 KB.
- **Store master archives on disk**: Save comprehensive catalogs as standalone Markdown files under `~/Desktop/Drafts_Oversized_Catalogs/` on disk. Write back only concise digests with file or artifact pointers to Drafts.
- **Deduplicate and clean orphans**: Purge redundant single-URL capture duplicates and unprocessed orphaned changes before large merges to prevent CloudKit sync queue wedging.

## Core Architecture: Read-Only SQLite + JXA Mutation

1. **Reads**: Always copy `DraftStore.sqlite` + `DraftStore.sqlite-wal` + `DraftStore.sqlite-shm` from `~/Library/Group Containers/GTFQ98J4YG.com.agiletortoise.Drafts/` to `/tmp/` before querying with SQLite. This provides instant, non-blocking zero-lock access across all columns (`ZUUID`, `ZCONTENT`, `ZCREATED_AT`, `ZFOLDER`, `ZCACHED_TAGS`). CoreData epoch offset: `978307200` seconds (2001-01-01).
2. **Mutations**: Never write directly to SQLite while Drafts.app is running (risks in-memory CoreData cache corruption and CloudKit sync conflicts). Use JXA (`osascript -l JavaScript`) rather than AppleScript.

---

## Why JXA over AppleScript for Drafts

- **Scale & Stability**: AppleScript uses linked-list representations that hit recursion stack limits (`error -10000`) on lists larger than ~500 UUIDs. JXA runs on JavaScriptCore and iterates over 20,000+ UUIDs in a standard V8-class loop.
- **Throughput**: JXA processes ~40–100 item mutations per second directly via Cocoa Scripting Bridges.
- **Zero String Escaping Fragility**: Native JSON passing (`JSON.parse()`) eliminates string delimiter hacks (`<<SEP>>`, `set text item delimiters`) and backslash-escaping bugs.

---

## High-Throughput JXA Batch Recipes

### 1. Batch Archiving Processed Drafts from Inbox

Write target UUIDs to a temporary JSON file (e.g. `/tmp/to_archive.json`) and run via JXA:

```javascript
ObjC.import("Foundation");

const path = "/tmp/to_archive.json";
const content = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null).js;
const ids = JSON.parse(content);

const app = Application("Drafts");
console.log("Archiving " + ids.length + " items via JXA...");

let count = 0;
for (let i = 0; i < ids.length; i++) {
  try {
    const d = app.drafts.byId(ids[i]);
    if (d) {
      d.folder = "archive"; // or "trash" / "inbox"
      count++;
    }
  } catch (e) {}

  if ((i + 1) % 500 === 0 || i === ids.length - 1) {
    console.log("  progress: " + (i + 1) + " / " + ids.length);
  }
}
console.log("Archived " + count + " drafts.");
```

Run headlessly:
```bash
osascript -l JavaScript /tmp/archive_worker.js
```

### 2. Fast Tagging Batches via `d.tagList`

Assign tags directly using the native `tagList` property. Drafts CoreData automatically encodes internal `ZZZ` delimiters (`ZZZtagZZZ`):

```javascript
const app = Application("Drafts");
for (let i = 0; i < items.length; i++) {
  try {
    const d = app.drafts.byId(items[i].id);
    if (d) {
      d.tagList = items[i].tags; // array of string tag names, e.g. ["reading", "arxiv", "ai"]
    }
  } catch (e) {}
}
```

---

## Data Invariants & Hard-Won Rules (From Live Production Audits)

- **Transactional Mutation Gate & Rollback Safety**:
  1. *Full-Field Snapshot First*: Before any mutation (tag, archive, trash, content replacement, empty-trash), snapshot *every* mutable field per UUID (`content`, `folder`, `tagList`, `flagged`), along with a `sha256` content hash and timestamp, into a rollback JSON map. Folder-only snapshots cannot revert tag rewrites or content replacements.
  2. *Reconcile Before Mutation*: Prove $100\%$ UUID presence and full content preservation on disk in master catalogs before touching live drafts.
  3. *Mandatory User Confirmation*: Before executing JXA, present the exact count, source folder scope, target action, and reviewed manifest path to the user. Never mutate without explicit confirmation.
  4. *Mutate Manifest Only*: Execute JXA mutations strictly on the confirmed UUID manifest.
  5. *Verify Post-State & Retain Rollback*: Query SQLite immediately to assert folder/tag counts match expectations. Retain the rollback mapping file.
- **Bounded Retry Cap & Graceful Pause**: When validating generated compendia or summaries, cap automated fix attempts at **2 retries**. If semantic defects remain, preserve the candidate file (`/tmp/candidate.md`), pause immediately, and report the specific issues for human review rather than running indefinitely. Presence of a UUID in a file is not a deep read; re-open the deliverable.
- **Incoming vs restored**: After a trash rollback, classify only drafts created since the last catalog. The restored set is already cataloged.
- **`Changes.sqlite` & `ZPROCESSED=0` Invariant**:
  - Never delete rows from `Changes.sqlite` or equate `ZPROCESSED = 0` with "orphaned records" to be purged.
  - `ZPROCESSED = 0` is the active Apple CloudKit sync backlog draining valid changes in background batches (~100 items/tick). Deleting rows corrupts the sync token state.
- **Line Counting Invariant**:
  - Never evaluate line counts on SQL substring queries (e.g. `substr(ZCONTENT, 1, 100)` truncates content and causes multi-paragraph drafts to appear as $< 10$ lines).
  - Always query full `ZCONTENT` and split via `len(content.splitlines())`. Never use `count('\n') + 1` (silently fails on classic Mac `\r` carriage returns).
- **Strict Regex Word Boundaries**:
  - Never use loose substring matches:
    - Bare `"ui"` matches inside `"building"` (falsely tagging AI safety articles as `frontend`).
    - Bare `"ss,"` matches inside `"Congress,"`, `"business,"`, or `"process,"` (falsely tagging math/history essays as Shadowsocks proxies).
    - Bare `"math"` matches inside `"polymath"`.
  - Always use compiled word boundaries: `\bui\b`, `\bmath\b`, `^\s*\[Proxy\]|\b(encrypt-method|ss://|vmess://)\b`.
- **No Raw JSON Syntax in Abstracts**:
  - Never treat lines inside `{ ... }` blocks as prose paragraphs. Extract human descriptions before the JSON block or parse field values (`:\s*"([^"]+)"`) and strip all JSON brackets/quotes. Reject any abstract starting with `"key":` or containing `": {`.
- **LaTeX Preamble & Boilerplate Rejection**:
  - Never title a LaTeX paper `\documentclass{article}` or summarize it as `\usepackage{...}`. Parse `\title{...}`, `\section{...}`, or mathematical theorems past the preamble.
  - Never summarize code as generic headings like `Script Breakdown`, `Key Insights`, or `# YOUR CODE HERE`.
- **Atomic Staging Workflow**: Always write generated compendia to a temporary file (`/tmp/candidate.md`), validate all gates (UUID set equality, line ceilings, size ceilings, zero raw syntax), and atomically cut over using `os.replace`.
- **Empty Clipper Scaffold (`> `)**: The Drafts web clipper inserts `> \n\n*Source*: [...]()` when clipping a page with no highlighted text selection. Do NOT treat `^\s*>\s*$` as a real markdown quote; real blockquotes must have text after the quote marker (`^\s*>\s*\S+`).
- **Canonical URL Deduplication**: Over long windows, 20–40% of bookmarks are duplicate saves of the same URL. Fold repeat saves into `dup×N` with the earliest date and combined note context before generating master catalogs. Keep the single richest annotation per URL and archive or trash the redundant copies.
