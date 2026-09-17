---
name: drafts-automation-golden-rule
description: "Hard size boundaries, disk offloading patterns, and JXA batch rules for Drafts.app automation to prevent CloudKit sync failures"
---

# Drafts.app Automation Invariants & Golden Rules

Operational rules, size boundaries, and batch invariants for Agile Tortoise Drafts on macOS derived from live CloudKit sync failure recovery and bulk cataloging.

## 1. The Golden Rule of Drafts Storage
- **Hard Payload Ceiling**: Never let any single draft or merge output exceed **300 KB (or ~5,000 lines)**. CloudKit strictly rejects individual `CKRecord` payloads approaching 1 MB, causing an infinite sync retry loop that wedges background sync.
- **Disk-First Offloading**: Store comprehensive master archives, raw transcripts, and multi-thousand line catalogs as standalone Markdown files on disk under `~/Desktop/Drafts_Oversized_Catalogs/` or project workspaces. Write back only concise digests with file or artifact pointers to Drafts.
- **Explicit User Confirmation**: Always present exact counts, source folder scope, target destination, and reviewed manifest path to the user, and require explicit confirmation before performing any write-back or mutation in Drafts.

## 2. Transactional Mutation Gate & Rollback Safety
Before performing batch folder migrations (archiving, trashing, or tagging):
1. **Full-Field Snapshot**: Snapshot every mutable field per UUID (`content`, `folder`, `tagList`, `flagged`), along with a `sha256` content hash and timestamp, into a local rollback JSON map.
2. **Pre-Mutation Disk Reconciliation**: Prove 100% UUID presence and full content preservation on disk in master catalogs before touching live drafts.
3. **Mutate Manifest Only**: Execute JXA mutations strictly on the confirmed UUID manifest.
4. **Post-State Verification**: Query SQLite immediately to assert folder/tag counts match expectations. Retain the rollback mapping file.

## 3. Data & Sync Invariants
- **`Changes.sqlite` & `ZPROCESSED=0`**: Never delete rows from `Changes.sqlite` or equate `ZPROCESSED = 0` with orphaned records. `ZPROCESSED = 0` is the active, healthy CloudKit sync backlog actively draining in background batches (~100 items/tick). Deleting rows corrupts the sync token state.
- **Line Counting**: Never evaluate line counts on SQL substring queries (e.g. `substr(ZCONTENT, 1, 100)` truncates content and causes multi-paragraph drafts to falsely appear as `< 10` lines). Always query full `ZCONTENT` and split via `len(content.splitlines())`. Never use `count('\n') + 1` (silently fails on classic Mac `\r` carriage returns).
- **Strict Regex Word Boundaries**: Never use unanchored substring matching for categorization (e.g., bare `"ui"` matches inside `"building"`, bare `"ss,"` matches inside `"Congress,"` or `"business,"`). Always use compiled word boundaries: `\bui\b`, `\bmath\b`, `^\s*\[Proxy\]|\b(encrypt-method|ss://)\b`.
- **Abstract Quality & Anti-Boilerplate**: Never feed lines inside JSON blocks (`{ ... }`) into prose extractors. Parse values explicitly and strip JSON syntax. Never title a LaTeX paper `\documentclass{article}` or summarize code as `Script Breakdown`.
- **Atomic Staging Workflow**: Always write generated compendia to a temporary candidate file (`/tmp/candidate.md`), validate all gates (UUID set equality, line ceilings, size ceilings, zero raw syntax), and atomically cut over using `os.replace` or `fcp`. Never overwrite the Desktop file before validators pass.
- **Incoming vs restored**: Classify drafts created since the last catalog window. Do not re-tag the batch you just restored from trash.
- **Two-retry cap**: After two failed quality gates on the same defect, pause and report. Do not start a third heuristic regen. Presence of a UUID in a markdown file is not a deep read.
