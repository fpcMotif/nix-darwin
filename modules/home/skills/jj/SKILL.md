---
name: jj
description: JJ workflows: inspect status/log/diff, atomic commits, hunk curation, bookmarks, and single-flight PR landing via jj pr.
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

- **Dry-run plan**: `jj pr <name> -n` prints the base, commits, and diff without pushing.
- **Update open PR**: `jj pr <name> -F FILE` (pass `-r @-` if new commits were added).
- **Draft PR body**:
  ```markdown
  ## Summary
  <shallow file tree, diff sketch, or 1-2 sentence core outcome>

  ## Evidence
  - **Before**: <failing command / error output>
  - **After**: <passing test command / verified output>

  ## Merge Danger
  **Door**: two-way | one-way
  **Blast Radius**: contained | broad
  ```
- **Completion criterion**: `jj status` shows clean empty `@` on `trunk()`.

## Interactive hunk curation

- `jj split -i [paths]` — partition `@` into atomic commits via diff editor (`space` toggles, `c` confirms).
- `jj squash -i [--from A --into B]` — move selected hunks between commits.
- `jj absorb` — fold working-copy hunks into the mutable ancestor that last touched those lines.

## Bookmarks & Git colocation

Colocated repository shares `.git` directly. Tools reading Git see `@-` automatically.

- **Create / Advance**: `jj bookmark create <name> -r <rev>` · `jj bookmark move <name> --to <rev> --allow-backwards`
- **Push / Sync**: `jj git push --bookmark <name>` · `jj git fetch`
- **External Git sync**: run `jj git import` after direct Git commands; align Git HEAD with `git checkout <branch>`.
