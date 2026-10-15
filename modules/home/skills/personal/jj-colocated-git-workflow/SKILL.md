---
name: jj-colocated-git-workflow
description: Repeatable Jujutsu (jj) colocated Git workflows: initialization, sideways bookmark moves, revisions, and single-flight landing.
---

# Jujutsu (jj) Colocated Git Workflows

Jujutsu colocated inside an existing Git repository (`.git` and `.jj` side by side). Git HEAD tracks `@-`.

## Core operations

- **Initialize**: `jj git init --colocate` in an existing Git checkout.
- **Sideways/backwards move**: `jj bookmark move <name> --to <rev> --allow-backwards` (required when moving non-descendant commits).
- **Restore revisions**: `jj restore --from <rev> [paths...]` (restores files into working copy `@`).
- **Align Git HEAD**: `git rev-parse HEAD` matches `jj log -r '@-' -T commit_id`. If detached after branch checkout, run `git checkout <branch>`.
- **Import external Git writes**: run `jj git import` if raw Git write commands were executed.

## Single-flight PR & landing

Run the entire commit, push, PR, merge, and sync sequence in one flight:

```sh
jj pr <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land
# or Code Mode runner:
bun run scripts/jj-ship.ts -n <name> -m "type(scope): msg" --land
```
