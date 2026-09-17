---
name: drafts-ledger
description: Drafts.app captures — digest a period of saved links and notes ("what did I save these two months", "summarize my Drafts", skill gaps from my captures), search or export them, or write a note back to Drafts. Wraps the drafts-ledger CLI; the Drafts MCP alone cannot list or search drafts.
---

# Drafts ledger

CLI: `~/.skillshub/drafts-ledger/bin/drafts-ledger.ts` (executable; `--help` is the flag reference — read it, do not guess flags). It reads a *copy* of the Drafts SQLite store (DB + WAL + SHM), so nothing here locks the app and nothing is stale. Every network or write step honours `--dry-run`; run the dry run first whenever the step costs requests or touches the user's notes.

The Drafts MCP (`mcp__drafts__*`) has `get`, `create`, `add_tags`, `archive`, `trash`, `flag`, but no list or search. The CLI reads; the MCP mutates existing drafts; the CLI's `create` / `append` / `prepend` write through the `drafts://` URL scheme (tested to ~100K-character URLs).

## The Golden Rule for Drafts Automation

Never let any single draft or merge output exceed 300 KB (or ~5,000 lines). If consolidating historical data:
- **No long lines or raw dumps**: Never store raw transcripts, multi-thousand line dumps, or long-line records in Drafts. Keep master catalogs and full-text archives on disk under `~/Desktop/Drafts_Oversized_Catalogs/`. Write back only concise digests with file or artifact pointers to Drafts.
- **Explicit user reconfirmation required**: Always ask for and receive explicit user confirmation before writing, creating, or appending any note back to Drafts.app.
- **Partition by period**: Split notes by quarter or month so each draft stays strictly under 300 KB.
- **Transactional mutation gate**: Snapshot full content, UUID, and original folder into a rollback JSON map before any folder changes. Prove 100% disk reconciliation of target UUIDs before executing JXA mutations.
- **Never touch `Changes.sqlite`**: Do not delete rows from `Changes.sqlite` or equate `ZPROCESSED = 0` with orphans. `ZPROCESSED = 0` represents the active, healthy CloudKit sync backlog draining in background batches.
- **Deduplicate and clean orphans**: Purge redundant single-URL capture duplicates before or after large consolidations. Keep the single richest annotation per canonical URL.

## Branches

### Search or look up

`search "<text>" --since 3m`, `get <uuid>`, `export --format urls`. Done when matches print with uuid and date.

### Write a note back

`create --file note.md --tag <t> --dry-run`, then without `--dry-run`. Tag, archive or trash an *existing* draft through the MCP. Done when `get <uuid>` (or the MCP's `drafts_get_current`) shows the note.

### Digest a period

The full pipeline; each step's output is the next step's input, so keep one work directory `W`.

1. **Scope.** `stats --since <window>` and confirm exclusions with the user. Default `--max-links 9`: drafts holding ten or more links are link dumps that distort counts. Print the bucket sizes back so the user can veto a bucket.
2. **Export → enrich → chunk.**
   `export --since … --max-links 9 --out W/items.jsonl`, then `enrich W/items.jsonl --dry-run` (request counts per kind; the cache under `~/.cache/drafts-ledger` makes re-runs free), then `enrich … --out W/enriched.jsonl`, then `chunk W/enriched.jsonl --out W/chunks`. Done when `manifest.json` lists every chunk and `enrich` reported metadata on the large majority of items (x.com and GitHub above 90 percent; web titles lower is normal — some hosts block).
3. **Inventory for the skill-gap read.** `reference/inventory.sh W` writes `installed_skills.md` and `gh_activity.md`. Skills live in six roots on this machine — skillshub (symlinked into `~/.claude/skills`, `~/.agents/skills`, `~/.codex/skills`), OMP's `~/.omp/agent/managed-skills`, pi packages under `~/.pi/agent`, factory/cursor/opencode, and Claude plugins — and the script scans all of them; a Claude-only inventory once produced install advice for packages pi already had. The gap analysis compares captures with what the user actually ships; without these files it degrades to guesswork.
4. **Read and synthesize.** With a workflow opt-in, run `reference/digest-workflow.js` through the Workflow tool with `{S: W, manifest: <manifest.json contents>, profile, period}` — Haiku reads each chunk, one synthesis per bucket, then best-writing, skill-gap and narrative agents, refuters per claim, a completeness critic with fix-ups. Without an opt-in, run the same chunk prompt from the script through the Agent tool per chunk and synthesize yourself. Done when reads equal chunks in the manifest (a chunk that fails structured output is a hole; re-run it), and every curated URL is confirmed with `rg -F` (query string stripped) against `W/items.jsonl`.
5. **Apply the critic before rendering.** The critic's addenda are corrections, not an appendix: patch `digest.json` (restore wrongly dropped items with metadata-grounded descriptions, fix reversed claims, add missing themes), keep the addenda as the audit trail, then `render W/digest.json --out W/digest.html --title …`. Publish the HTML as an artifact; `create` the `.md` twin as a Drafts note with the artifact link on the first line (enforcing the 300 KB / 5,000 lines ceiling; if oversized, store master catalogs in `~/Desktop/Drafts_Oversized_Catalogs/` and write back a partitioned summary).

## What the data does not confess

- **NOTE is rarely the user's voice.** Most NOTE fields are the web clipper's `*Source*: […]() / ___` scaffold or pasted tweet text from the mobile share sheet (`?s=12` links). Attribute to the author, and treat the rare first-person Chinese or English note as the strongest signal in the set.
- **dup×N is intent.** The exporter folds repeat saves of one URL into a count; a second save is a stronger vote than any like count. Keep it visible in highlights and skill gaps.
- **Bursts are imports.** A hundred-plus YouTube saves on one day is a watch-later import, not a day's viewing; read early-window volume as backlog, late-window volume as current interest.
- **Refute against the chunk line, not memory.** Verifiers grep the chunk files; a claim that embellishes the captured title or description is a refutation even when the URL is real, so the critic must re-check drops before they are final.
- **SQLite `immutable=1` reads are stale** (the WAL is ignored). The CLI copies the store; do the same for any ad-hoc query.
