---
name: jj
description: Use when working in a Jujutsu (jj) repository — for jj workflows (status, log, diff, new, describe, squash, split, rebase, bookmarks, undo, git interop) and for hunk-level diff review. Triggers on "jj"/"jujutsu", reviewing or splitting changes, crafting atomic commits, or any version-control task in a repo that contains a `.jj` directory.
---

# Jujutsu (jj)

A Git-compatible VCS with no staging area. Use this skill instead of raw `git`
in any repo that has a `.jj/` directory (`jj root` succeeds). Diffs render
through delta (configured in `modules/home/jujutsu.nix`), so `jj diff`/`jj show`
already produce syntax-highlighted hunks.

## Mental model (how jj differs from git)

- **The working copy IS a commit.** Your uncommitted edits live in the commit
  `@` (the "working-copy commit"), which jj amends automatically on every
  command. There is **no `git add`/staging** — what you see is what's committed.
- **Change ID vs commit ID.** Every change has a stable *change ID* (letters,
  e.g. `qpvuntsm`) that survives rewrites/rebases, plus a *commit hash* (hex)
  that changes when the commit is rewritten. Address commits by either; the
  short prefix shown in `jj log` is enough.
- **Everything is undoable.** `jj undo` reverts the last operation; `jj op log`
  shows the full history of operations. You can recover from almost anything.
- **Bookmarks are jj's branches.** They do not move automatically — you advance
  them explicitly. Git branches appear as bookmarks via the git backend.

## Core loop

| Task | Command |
|------|---------|
| What changed in the working copy | `jj status` (alias `jj st`) |
| History graph | `jj log` (default command here); scope with `-r <revset>` |
| Start a new, empty change | `jj new` (on top of `@`) or `jj new <rev>` |
| Set/began the current message | `jj describe -m "msg"` (alias `jj desc`) |
| Finish change + start the next | `jj commit -m "msg"` |
| Make an existing commit the working copy | `jj edit <rev>` |
| Move `@`'s changes into its parent (amend) | `jj squash` |
| Drop a commit | `jj abandon <rev>` |
| Undo the last operation | `jj undo` (then `jj op log` / `jj op restore`) |

`jj new` then editing files is the normal way to begin work: do the edits, then
`jj describe -m "..."` (or `jj commit`) to name the change.

## Diff & hunk-level review (the main reason to reach for jj here)

| Goal | Command |
|------|---------|
| Review the current change | `jj diff` (delta hunks of `@` vs its parent) |
| Review what a specific commit introduced | `jj diff -r <rev>` |
| Compare two revisions | `jj diff --from <a> --to <b>` |
| Limit to paths | `jj diff <path>...` |
| Commit message + its diff | `jj show <rev>` |
| Raw git-format patch (for piping/applying) | `jj diff --git` |
| Stat summary only | `jj diff --stat` |

**Interactive hunk curation** — pick changes hunk-by-hunk in jj's built-in
diff editor (space to toggle a hunk, `c` to confirm):

- `jj split -i` — carve `@` into two (or more) commits, choosing which hunks go
  into the first. The cleanest way to turn one messy change into atomic commits.
- `jj split -i <paths>` — restrict the split to specific files.
- `jj squash -i` — move only selected hunks from `@` into its parent (the rest
  stay in `@`). `jj squash -i --from <a> --into <b>` moves hunks between any two
  commits.
- `jj absorb` — automatically distribute each working-copy hunk into the nearest
  mutable ancestor commit that last touched those lines. Ideal for fixups: edit
  freely, then `jj absorb` to fold the changes back where they belong.

**Reviewing a series before pushing:** `jj log -r 'trunk()..@'` to see the
stack, then `jj show <rev>` (or `jj diff -r <rev>`) on each to review per-commit
hunks.

## Bookmarks & Git interop

| Task | Command |
|------|---------|
| List bookmarks | `jj bookmark list` (alias `jj b l`) |
| Create a bookmark at a rev | `jj bookmark create <name> -r <rev>` |
| Move a bookmark | `jj bookmark move <name> --to <rev>` (or `set -r`) |
| Fetch from remotes | `jj git fetch` |
| Push a bookmark | `jj git push --bookmark <name>` |
| Create a bookmark for `@` and push | `jj git push -c @` |
| Import/export refs after raw git use | `jj git import` / `jj git export` |

When co-located with git (`.git` present), jj and git share the same commits;
run `jj git import` if you used a `git` command directly so jj sees the change.

## Revsets (the query language)

`@` working copy · `@-` parent · `@--` grandparent · `root()` · `trunk()`
(the main branch) · `a..b` (in b but not a) · `a::b` (ancestors of b within a)
· `mine()` · `description("text")` · `bookmarks()` · `heads(...)`.
Common: `jj log -r 'trunk()..@'`, `jj diff -r 'description("WIP")'`.

## Rebase & history editing

- `jj rebase -d <dest>` — rebase `@` (and descendants) onto `<dest>`.
- `jj rebase -s <src> -d <dest>` — rebase `<src>` and its descendants.
- `jj rebase -b <branch> -d <dest>` — rebase a whole branch.
- Conflicts are recorded *in commits* (first-class) — jj never blocks you mid
  rebase. Resolve later by editing the conflicted commit (`jj edit`, fix, done),
  then descendants auto-update.

## Safety & recovery

- `jj undo` — undo the last op. `jj op log` — every operation; `jj op restore
  <op>` — jump the whole repo back to a prior state.
- `jj abandon` removes a commit but it stays in the op log, so it is recoverable.
- There is no "detached HEAD" footgun and no stash needed — just `jj new` to set
  work aside on another change and `jj edit` to return.

## Agent etiquette in jj repos

- Inspect with `jj status` + `jj diff` before changing anything — no `git
  status`/`git diff` (they miss jj's working-copy commit semantics).
- Make atomic commits by editing freely then `jj split -i` / `jj absorb`, rather
  than trying to stage hunks (there is no index).
- Never assume a bookmark moved — advance it explicitly before `jj git push`.
- If the user also runs raw `git` in the repo, `jj git import` before relying on
  `jj log`.
