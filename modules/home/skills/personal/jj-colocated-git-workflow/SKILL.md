---
name: jj-colocated-git-workflow
description: "Repeatable Jujutsu (jj) colocated Git workflows: initialization (--colocate), sideways bookmark updates (--allow-backwards), and cross-revision restoration (--from)"
---

# Jujutsu (jj) Colocated Git Workflows & Bookmark Management

Procedures and recovery patterns when using Jujutsu (`jj`) colocated inside an existing Git repository.

## Colocated Initialization

When starting work in a Git repository that does not yet have a `.jj` directory:
```bash
jj git init --colocate
```
This enables `jj` while sharing the working copy and `.git` refs directly.

## Handling Bookmark Moves During Rewrites & Splits

When reorganizing, splitting, or updating a bookmark to a commit that is not a fast-forward descendant:
- Plain `jj bookmark move <name> --to <rev>` will fail with:
  `Error: Refusing to move bookmark backwards or sideways: <name>`
- Use `--allow-backwards`:
  ```bash
  jj bookmark move <name> --to <rev> --allow-backwards
  ```

## Restoring Exact Revisions

To restore files from a target revision into the working copy (`@`):
```bash
# Restore entire tree from revision
jj restore --from <rev>

# Restore specific files or directories
jj restore --from <rev> <paths...>
```

## Git Sync & Alignment

- In colocated repos, running `jj git export` outputs `No export needed in colocated workspaces.` because changes are committed directly into Git's object store.
- If Git's HEAD becomes detached after `jj` operations, align Git's active branch pointer with:
  ```bash
  git checkout <branch-name>
  ```
