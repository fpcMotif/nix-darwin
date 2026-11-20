## Parallel checkouts

- **Clone**: Use `jj git clone URL PATH`. Keep unfamiliar repositories outside automatically trusted direnv roots.
- **JJ**: Create parallel JJ checkouts with `jj workspace add --name NAME ../REPO.NAME`. Never initialize JJ inside a Git worktree.
- **Git**: In Git-only repositories, create a parallel checkout with `wt switch --create BRANCH`. Run later commands in its sibling path.
- **Cleanup**: `wt remove BRANCH` refuses uncommitted changes. Pass `--force` only when the user asks.
- **Subagents**: Claude Code's `isolation: "worktree"` runs `agent-checkout create`. In a `.jj` repository it makes a JJ workspace that holds a copy of your uncommitted work. Antigravity subagents still get Git worktrees.
- **Land**: When a subagent finishes in its own checkout, run `agent-checkout land NAME` in the main workspace. NAME is the JJ workspace name, the Git branch, or the checkout path. It moves the commits under `@` and removes the checkout.
