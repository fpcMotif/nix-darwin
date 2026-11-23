---
name: jj
description: "JJ workflows: inspect status/log/diff, atomic commits, hunk curation, bookmarks, and single-flight PR landing via jj pr. Use also when another skill names a Git or GitHub step (git diff, git commit, git push, gh pr create) in a JJ workspace; it maps each one to JJ."
---

# Jujutsu (jj)

Working copy commit `@` amends automatically. Git HEAD tracks `@-`.

## Core loop

| Action | Command | Note |
|---|---|---|
| Status & Diff | `jj status` · `jj diff` · `jj diff --stat` | Review changes in `@` vs `@-` |
| Stack History | `jj log -r 'trunk()..@'` · `jj log -n 5` | View current branch commits |
| Name / Commit | `jj describe -m "type(scope): msg"` | Name `@` without advancing |
| Finish / Next | `jj commit -m "type(scope): msg"` | Commit `@` and open empty `@` |
| Amend Parent | `jj squash` | Move `@` changes into `@-` |
| Switch / Edit | `jj new <rev>` · `jj edit <rev>` | Branch from `<rev>` or edit in place |
| Rebase | `jj rebase -d <dest>` · `jj rebase -s <src> -d <dest>` | Conflicts store in commits; resolve with `jj edit` |
| Restore / Undo | `jj restore --from <rev> [paths]` · `jj undo` · `jj op log` | Everything in the op log is reversible |

## Pull requests & landing

Deterministic VCS pipeline: commit, push, open/update PR, merge to trunk, fetch, and advance `@` in one command:

```sh
# Single-flight: commits @, opens PR, merges into trunk, fetches, and advances @ onto trunk
jj pr <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land

# Commit only some paths; the rest stays in @ and moves onto trunk with it
jj pr <name> -m "type(scope): msg" -F /path/to/body.md --land -- path/a path/b

# In nix-config, the same flight from the checkout, before a rebuild:
nix run .#martin.jj-pr -- <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land
```

- **Flag check**: an older installed `jj pr` lacks `-m`, `--land`, or paths. Run `jj pr --help` first. Without them, run `jj commit -m MSG [PATHS]`, then `jj pr <name> -F FILE`, then `gh pr merge`.

- **Gate on CI**: `--land` merges at once. Use `--land --wait` to merge only after the PR's checks pass. A failed check leaves the PR open.
- **Dry-run plan**: `jj pr <name> -n` prints the base, commits, and diff without pushing.
- **Update open PR**: `jj pr <name> -F FILE` (pass `-r @-` if new commits were added).
- **PR body**: write the `-F` file with the `pr` skill. It owns the template (Summary, Evidence, Merge Danger).
- **Completion criterion**: `jj status` shows clean empty `@` on `trunk()`.

## Interactive hunk curation

- `jj split -i [paths]` — partition `@` into atomic commits via diff editor (`space` toggles, `c` confirms).
- `jj squash -i [--from A --into B]` — move selected hunks between commits.
- `jj absorb` — fold working-copy hunks into the mutable ancestor that last touched those lines.

## Skills written for Git

Many skills (Matt Pocock's `code-review`, `improve-codebase-architecture`, Claude's `simplify`, Impeccable) name Git and GitHub commands. In a `.jj` workspace, keep the skill's intent and run the JJ command from this table.

The work in progress is the commit `@`, not uncommitted files. Where a skill says `HEAD`, use `@`. Use `@-` only when `@` is empty.

| The skill says | Run under JJ |
|---|---|
| `git diff` · `git diff --staged` | `jj diff` (there is no staging area) |
| `git diff X...HEAD` | `jj diff --from 'fork_point(X \| @)' --to @` |
| `git merge-base A B` | revset `fork_point(A \| B)` |
| `git log X..HEAD --oneline` | `jj log -r 'X..@' --no-graph -T builtin_log_oneline` |
| `git log --oneline` | `jj log -r '::@' -n 30` |
| `git show REV` | `jj show REV` |
| `git rev-parse REV` | `jj log --no-graph -r REV -T commit_id` |
| `git blame PATH` | `jj file annotate PATH` |
| `git add` + `git commit` | `jj commit -m MSG [PATHS]` |
| `git commit --amend` | `jj squash`, or `jj describe -m MSG` for the message |
| `git checkout -b NAME` · `git switch` | `jj new REV`; name a bookmark only when pushing |
| `git stash` | `jj new @-`; the parked work stays in its own commit |
| `git restore PATH` · `git checkout -- PATH` | `jj restore PATH` |
| `git reset --hard` | `jj abandon @`, or `jj undo` for the last operation |
| `git pull` · `git fetch` + rebase | `jj git fetch && jj rebase -d 'trunk()'` |
| `git push` + `gh pr create` · `gh pr merge` | `jj pr NAME -m MSG -F BODY [--land]` |

Git and `gh` stay for what JJ does not cover:

- **GitHub objects**: `gh issue`, `gh pr view`, `gh pr checks`, review comments, and `gh api`. Pass the PR number and `-R owner/repo`.
- **Pickaxe search**: `git log -m -S TEXT`.
- **Git-only tools**: give them commit hashes (the `git rev-parse` row). A tool that reads Git state itself, such as `impeccable signals`, needs no change: Git shows the content of `@` as uncommitted changes.
- **Read-only Git** (`git show`, `git diff A B`, `git log`) is safe on commit hashes. Route every write (`commit`, `rebase`, `stash`, `push`) through the table. After a direct Git write, follow External Git sync below.

## Bookmarks & Git colocation

Colocated repository shares `.git` directly. Tools reading Git see `@-` automatically.

- **Create / Advance**: `jj bookmark create <name> -r <rev>` · `jj bookmark move <name> --to <rev> --allow-backwards`
- **Push / Sync**: `jj git push --bookmark <name>` · `jj git fetch`
- **External Git sync**: run `jj git import` after direct Git commands; align Git HEAD with `git checkout <branch>`.
