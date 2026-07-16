# Drafts bulk link consolidation

Date: 2026-07-16
Status: approved design

## Goal

Add a fast, resumable MCP operation for Drafts on macOS that:

- finds every Inbox or Archive draft whose entire content is one logical line;
- matches `x.com`, `youtube.com`, or `github.com`, case-insensitively;
- includes tagged and untagged drafts;
- writes one untagged report with each exact line included once globally;
- groups lines by `x.com`, then `youtube.com`, then `github.com`;
- archives every unchanged source draft after report verification;
- never deletes a draft or writes to Drafts' SQLite databases.

The current library has 90,974 live drafts. The target snapshot contains 16,995
source drafts and 14,136 unique lines. The report is about 822 KB.

## Why the official MCP path fails

`@agiletortoise/drafts-mcp-server` implements filtered reads as AppleScript
`every draft whose content contains ...`. A clean, single `x.com` query exceeds
Drafts' 120-second AppleEvent timeout. Timed-out `osascript` children can keep
Drafts busy, causing later `Connection is invalid` errors.

Lightweight MCP calls remain healthy. The failure is the broad AppleScript scan,
not MCP transport, permissions, or Drafts installation.

## Selected architecture

Use a small global MCP supervisor plus one versioned Drafts action.

### MCP supervisor

The supervisor owns:

- `preview`, `apply`, `resume`, `status`, and `restore` tools;
- operation locking;
- action installation and version checks;
- request/result mailbox handling;
- retries and owned-process cleanup;
- progress reporting;
- the read-only SQLite fallback planner.

It never performs broad AppleScript queries. It invokes the action through
Drafts' documented `/runAction` URL with a small command on an unsaved draft.
The URL returns immediately; the supervisor does not hold an AppleEvent open
while the action works.

### Drafts action

The action owns all Drafts mutations through documented scripting APIs:

- `Draft.query` and `Draft.find`;
- `Draft.create`;
- `draft.folder = "archive"`;
- `draft.update()`.

Each invocation has a bounded workload. It reads a command from a temporary
unsaved draft, writes a compact JSON result to its local mailbox, and persists
its journal with `FileManager.createLocal()`. No saved control draft is created.

The mailbox lives in Drafts' local Documents container. Requests and results use
random IDs, restrictive permissions, content hashes, write-to-temp plus atomic
rename, and regular-file/no-symlink checks. The action accepts only known command
schemas and matching operation IDs.

The action bundle is generated from versioned source. Installation or upgrade is
explicit: the supervisor opens the `.draftsAction` bundle and waits for user
confirmation. Nix does not own Drafts' mutable action database.

### Planner selection

The documented Drafts API is preferred.

1. Run three native `Draft.query` calls: `x.com`, `youtube.com`, `github.com`.
2. Post-filter every result for exact substring and one-line rules.
3. Attempt native planning once behind a 20-second preview budget.
4. If it errors, misses the deadline, or completes in more than 10 seconds,
   record native planning as unsuitable for this library and use SQLite for this
   and later operations.

The fallback opens `DraftStore.sqlite` with `mode=ro` and `PRAGMA query_only=ON`
inside one read transaction. It also sets `trusted_schema=OFF`, uses a bounded
busy timeout, and reads the live WAL normally rather than using `immutable=1`.
It validates the expected table and column fingerprint before reading. A schema
mismatch fails closed and never guesses.

The fallback may write only a manifest file in Drafts' local Documents mailbox.
It must never issue SQL writes, alter pragmas persistently, or touch WAL files.
The native action consumes the manifest and performs every Drafts mutation.

Current read-only SQL planning takes about 0.07 seconds.

## Matching and merge rules

A source is eligible when:

- `folder` is Inbox or Archive;
- it is not hidden or trashed;
- content contains no LF or CR;
- lowercase content contains at least one configured domain.

Content equality is exact. No trimming, Unicode normalization, case folding, or
URL canonicalization occurs before deduplication.

Duplicate source drafts remain separate archive targets. Their content appears
once in the report.

If one line matches several domains, it appears once under the first category:

1. `x.com`
2. `youtube.com`
3. `github.com`

Within each section, lines sort by the representative source's creation date,
then UUID. The representative is the earliest source, then lowest UUID.

The report shape is:

```text
# Classified single-line drafts

## x.com
<exact unique lines>

## youtube.com
<exact unique lines>

## github.com
<exact unique lines>
```

The report has no tags. Source content and tags remain unchanged.

## Transaction model

An operation uses this state machine:

```text
planned
  -> report-created
  -> report-verified
  -> archiving
  -> archive-verified
  -> completed
```

Errors move the operation to `paused` or `conflicted`, never to a false success.

The operation ID is a SHA-256 digest over:

- rule version;
- sorted source UUIDs;
- original folders;
- creation dates;
- exact-content hashes.

The journal records the report UUID, report hash, source manifest, completed
batches, conflicts, timestamps, and action version.

Only one operation may hold the lock. A stale lock contains its PID, start time,
and operation ID and may be reclaimed only when that PID is gone.

## Safe execution

### Preview

`preview` is read-only. It returns:

- source and unique-line counts;
- category counts;
- duplicate count;
- Inbox sources that would move;
- already archived sources;
- report byte size;
- planner used;
- operation ID.

### Apply

`apply` requires the preview's operation ID. Before creating the report, it
revalidates every source UUID, content hash, and folder. Drift aborts with no
mutation.

The action then:

1. creates the untagged report in Inbox;
2. reads it back and verifies its exact hash;
3. archives unchanged Inbox sources in adaptive batches;
4. verifies every source is in Archive;
5. verifies the report remains in Inbox and unchanged.

Already archived sources are verified but not rewritten.

Each batch targets 5 seconds and is capped at 250 updates. The supervisor keeps
each action invocation below 20 seconds. It triggers the next batch only after
the prior result file is complete and verified.

### Mid-run changes

Before archiving a source, the action verifies its exact content hash. A changed,
trashed, or missing source is skipped and recorded as a conflict. The operation
stops as `conflicted`; it never archives changed data silently.

If the report changes, execution pauses immediately. Resume requires restoring
the expected report or starting a fresh preview.

### Resume and idempotence

`resume` continues from the first unfinished batch. Completed batches are not
replayed.

A completed-source ledger stores UUID plus content hash. Future previews exclude
the same source revision. If a source's content changes, it becomes eligible
again.

If the ledger is missing while an existing classified report is present, the
tool refuses to create another report without an explicit rebuild command.

### Restore

`restore` is journal-driven:

- sources originally in Inbox return to Inbox;
- sources originally in Archive stay there;
- changed sources are skipped and reported;
- the report is archived, never deleted.

Restore is resumable and verified with the same batch rules. Completed-source
ledger entries are removed only after their source restoration is verified.

## Failure handling

- Kill only stale children belonging to this tool. Never kill another agent or
  its Drafts query.
- A timed-out owned action request gets one bounded cleanup. Drafts may be
  restarted only while this tool holds its operation lock and no unrelated
  Drafts automation process is active. The operation then resumes from journal.
- Three repeated failures pause the operation and return exact diagnostics.
- No archive batch starts before report verification.
- No cleanup removes journals, manifests, reports, or source drafts.

## Packaging and configuration

`nix-config` owns the immutable helper, action source, tests, and MCP
registration logic. It does not own Drafts' database, action list, journals, or
other mutable app data.

Expected implementation seams:

- `pkgs/drafts-bulk-mcp.nix`;
- `pkgs/drafts-bulk-mcp/` for the MCP server and action source;
- `modules/home/drafts-bulk-mcp.nix` for Darwin-only installation;
- activation that registers only the named `drafts-bulk` MCP entry through each
  client's supported CLI, preserving the rest of the runtime-managed config;
- explicit action install/upgrade command.

The existing `drafts` MCP remains available for small interactive operations.
The new `drafts-bulk` MCP owns only bounded bulk workflows.

## Tool contract

Expose:

- `drafts_bulk_preview`
- `drafts_bulk_apply`
- `drafts_bulk_resume`
- `drafts_bulk_status`
- `drafts_bulk_restore`
- `drafts_bulk_install_action`

All mutating tools return the operation ID, phase, processed count, remaining
count, conflicts, report UUID, and verification status.

## Verification

### Unit tests

- exact one-line detection, including CR-only content;
- ASCII case-insensitive domain matching;
- global exact-content deduplication;
- category priority;
- representative selection and ordering;
- report rendering and hashing;
- operation state transitions;
- lock recovery;
- resume, conflict, and restore behavior;
- SQLite schema fingerprint rejection.

### Integration tests

Use a fixture SQLite database and a fake Drafts action adapter to prove:

- preview causes no writes;
- report verification precedes archive calls;
- retries do not duplicate updates;
- changed sources remain unarchived;
- completed operations are idempotent;
- restore affects only sources originally in Inbox.

### Live acceptance

On the real library:

1. preview completes without an AppleEvent timeout;
2. preview reports 16,995 sources and 14,136 unique lines for the current
   snapshot, unless the library changed;
3. create and verify one report;
4. archive all unchanged matching sources;
5. verify report content, folder, and no tags;
6. verify every unchanged source is archived;
7. run preview again and confirm zero already-processed source revisions;
8. restart the MCP and verify completed status survives.

## Non-goals

- deleting or trashing source drafts;
- direct SQLite writes;
- changing source content or tags;
- generic Drafts search replacement;
- iOS execution;
- background monitoring;
- automatic action installation without user confirmation.

## References

- [Draft scripting API](https://scripting.getdrafts.com/classes/Draft)
- [Drafts URL schemes and `/runAction`](https://docs.getdrafts.com/docs/automation/urlschemes)
- [Drafts local file API](https://scripting.getdrafts.com/classes/FileManager)
- [Drafts action installation](https://docs.getdrafts.com/docs/extending/directory)
