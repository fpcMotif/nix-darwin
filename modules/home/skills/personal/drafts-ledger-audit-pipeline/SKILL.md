---
name: drafts-ledger-audit-pipeline
description: Repeatable procedure for running the drafts-ledger pipeline over large historical windows with recursive primary-source auditing and safe MCP draft creation.
---

# Drafts Ledger Pipeline Execution & Snapshot Audit

Procedure for executing the full `drafts-ledger` synthesis pipeline across large historical date windows without corrupting or modifying existing ledger drafts.

## 1. Safety & Invariance Rules
- **Never mutate or delete existing ledger drafts**: When creating a new ledger period (e.g. H1 2026 when July-August 2026 already exists), locate existing notes via `drafts-ledger search "Capture Ledger"` and ensure their UUIDs are never passed to `append`, `prepend`, or MCP `drafts_update_draft`.
- **Prefer MCP for Large Writes**: The CLI `create` command routes via `drafts://x-callback-url/create`. For large digests (>50KB–100KB), macOS URL string limits can truncate or fail to open. Use `xd://mcp__drafts_create_draft` and `xd://mcp__drafts_update_draft` to write the full payload safely via native IPC.
- **The Golden Rule (300 KB / ~5,000 Lines Ceiling)**: Never allow any single draft or merge output to exceed 300 KB or ~5,000 lines. CloudKit sync stalls and rejects records when payloads approach Apple's 1MB CKRecord boundary.
  - **No long lines or raw dumps**: Never write raw transcripts, multi-thousand line logs, or unformatted dumps to Drafts. Store master catalogs as standalone Markdown files on disk under `~/Desktop/Drafts_Oversized_Catalogs/`. Write back only concise digests with file or artifact pointers to Drafts.
  - **Explicit user reconfirmation required**: Never create or append notes to Drafts without explicit user confirmation.
  - When consolidating historical data, partition notes strictly by quarter or month.
- **Transactional Mutation Gate**: Before archiving or trashing any draft:
  1. Snapshot full text, UUID, and original folder (`ZFOLDER`) into a rollback JSON file.
  2. Reconcile 100% of target UUIDs on disk in master markdown catalogs before executing mutations.
  3. Mutate only the verified manifest via JXA and confirm post-mutation folder counts.
  4. Retain rollback mapping for safe restoration if needed.
- **`Changes.sqlite` Invariant**: Never delete rows from `Changes.sqlite` or treat `ZPROCESSED = 0` as orphaned records. `ZPROCESSED = 0` represents the active, healthy CloudKit sync backlog actively draining in background batches.
- **Clean Orphans and Duplicates**: Before generating digests, run JXA deduplication to move duplicate single-URL drafts to trash, keeping only the single richest annotated draft per URL.
## 2. Fast Enrichment & Caching
`drafts-ledger enrich` caches metadata under `~/.cache/drafts-ledger/{repos,tweets,youtube,arxiv,web}.jsonl`.
- Before running live network sweeps over thousands of keys, run `drafts-ledger enrich <items.jsonl> --dry-run` to inspect cached vs uncached counts.
- For bulk enrichment:
  - Repos: Batched via GitHub GraphQL (100 repos/query).
  - arXiv: Batched via arXiv Export API (50 IDs/query).
  - YouTube: Fast concurrent oEmbed queries (`--concurrency 24`).
  - Twitter / x.com: Fetched via `https://api.fxtwitter.com/<user>/status/<id>` with 8–12 workers.
  - Web: Fetch HTML meta tags (`og:title`, `og:description`, `<title>`) with 32 workers; exclude heavy or blocked domains (`instagram.com`, `threads.com`, `drive.google.com`, `amazon.*`).

## 3. Recursive Primary Source Audit
When auditing curated highlights:
1. Extract all unique URLs from `best_writing`, bucket `top_highlights`, and `install_or_adopt`.
2. Cross-reference each URL against the cache or fetch live page snapshots.
3. Verify:
   - URL existence in `items.jsonl` (using `rg -F` with query parameters stripped).
   - Grounding: ensure the why/claim in the digest matches the actual article content, author, stars, or abstract without invented interpretations.
   - Quality validation: assert zero raw JSON key/value fragments (`": {`, `"key":`), zero raw LaTeX preambles (`\documentclass`), and verified title/abstract entity agreement across all entries.
   - For 404s on older URLs, verify the historical record in `items.jsonl` to confirm capture authenticity.
## 4. Render & Delivery
1. Assemble `digest.json` matching `drafts-ledger render` schema.
2. Render both HTML and Markdown:
   ```bash
   drafts-ledger render W/digest.json --out W/digest.html --title "Capture Ledger, <Period>" --sub "Drafts app · <Count> single-link captures"
   ```
3. Prepend the full artifact report link (`file://...` or artifact URL) on line 3 of the Markdown twin.
4. Create the new note in Drafts with tags: `summary`, `<period-tag>`, `github`, `twitter`, `blog`. Verify note size $\le 300\text{ KB}$; if exceeding, split by month or store the master catalog on disk under `~/Desktop/Drafts_Oversized_Catalogs/` and link the file.
