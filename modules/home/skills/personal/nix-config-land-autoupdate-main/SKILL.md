---
name: nix-config-land-autoupdate-main
description: Use when landing recent auto-update and local Jujutsu work into main in this nix-config repository.
---

# Land auto-update and local work

Use this procedure when `nix-config` has a recent auto-update, one or more local PR branches, and working-copy changes that must land on `main`.

## Map first

1. Run `jj status`, `jj log -r 'trunk()..@'`, and `jj bookmark list`.
2. Run `jj git fetch` before deciding what is current.
3. Inspect candidate PRs with `gh pr list`, `gh pr view N`, and `gh pr checks N`.
4. Inspect failed checks before landing. Distinguish source failures from rolling-pin hash drift.
5. Review `jj diff --stat` and preserve the working copy before rewriting history.

## Preserve and merge

1. Name the working copy: `jj describe -m "<local change>"`.
2. Preserve it: `jj bookmark create local-agent-work -r @`.
3. Create an integration merge:

   ```sh
   jj new main <fix-bookmark> @ -m "merge: land auto-update fixes and local agent work"
   ```

4. Resolve conflicts deliberately. Prefer the preserved local tree when it already contains the fix, then verify the resulting file against both parents.
5. Run `jj resolve --list`. After editing a merge conflict, run `jj new -m "verify integrated work"` so Jujutsu snapshots the resolution into the merge commit, then abandon the temporary empty child.
6. Move `main` to the resolved merge commit:

   ```sh
   jj bookmark move main --to <merge-revision>
   ```

## Verify and land

1. Run `just check`.
2. If it reports a fixed-output mismatch for the rolling Bun or SF Mono pin, run `just refresh-rolling`, describe the resulting change, snapshot it with `jj new`, and move `main` to that pin-refresh commit.
3. Run `just check` again.
4. Run `just verify-skills` when agent-skill surfaces changed.
5. Push only the verified bookmark: `jj git push --bookmark main`.
6. Verify remote PR state with `gh pr view N` and final local state with `jj status`.

## Invariants

- Preserve local work before any merge or rebase.
- Keep auto-update commits already present on `main`; do not replay them.
- Treat rolling fixed-output hash failures as pin drift, not as permission to skip checks.
- Push `main` only after the integrated tree passes `just check`.
