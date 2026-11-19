## Parallel checkouts

The workspace backend is dojjo, an experimental layer over JJ workspaces. Worktrunk is not installed.

- **Jujutsu**: In a `.jj` repository, run `djo switch --create NAME`. It prints the new sibling path; run later commands there.
- **Base**: `--create` starts from `trunk()`. Without a remote trunk bookmark that is the empty root commit, so pass `--base REV`.
- **Switch**: Use `djo switch NAME` and `djo list`. Call the result a JJ workspace, never a Git worktree.
- **Cleanup**: Run `jj status` inside the workspace first. Then run `jj workspace forget NAME` and delete its directory.
- **Destructive**: `djo remove`, `djo merge`, and `djo prune` abandon revisions or delete directories. Run them only when the user asks.
- **Git**: In a Git-only checkout, use `git worktree add ../REPO.BRANCH -b BRANCH`.
- **Subagents**: Claude Code's `isolation: "worktree"` runs `agent-checkout create`. In a `.jj` repository it makes a JJ workspace that holds a copy of your uncommitted work. Antigravity subagents still get Git worktrees.
- **Land**: When a subagent finishes in its own checkout, run `agent-checkout land NAME` in the main workspace. NAME is the JJ workspace name, the Git branch, or the checkout path. It moves the commits under `@` and removes the checkout.
- **Mismatch**: If `djo` finds no JJ repository, stop and report it. Never initialize one to proceed.
