## Parallel checkouts

The workspace backend is dojjo, an experimental layer over JJ workspaces. Worktrunk is not installed.

- **Jujutsu**: In a `.jj` repository, run `djo switch --create NAME`. It prints the new sibling path; run later commands there.
- **Base**: `--create` starts from `trunk()`. Without a remote trunk bookmark that is the empty root commit, so pass `--base REV`.
- **Switch**: Use `djo switch NAME` and `djo list`. Call the result a JJ workspace, never a Git worktree.
- **Cleanup**: Run `jj status` inside the workspace first. Then run `jj workspace forget NAME` and delete its directory.
- **Destructive**: `djo remove`, `djo merge`, and `djo prune` abandon revisions or delete directories. Run them only when the user asks.
- **Git**: In a Git-only checkout, use `git worktree add ../REPO.BRANCH -b BRANCH`.
- **Host tools**: A host's built-in worktree feature makes Git worktrees. Do not use it in a `.jj` repository.
- **Mismatch**: If `djo` finds no JJ repository, stop and report it. Never initialize one to proceed.
