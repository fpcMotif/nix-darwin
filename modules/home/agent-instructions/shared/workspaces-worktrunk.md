## Parallel checkouts

- **Clone**: Use `jj git clone URL PATH`. Keep unfamiliar repositories outside automatically trusted direnv roots.
- **JJ**: Create parallel JJ checkouts with `jj workspace add --name NAME ../REPO.NAME`. Never initialize JJ inside a Git worktree.
- **Git**: In Git-only repositories, create a parallel checkout with `wt switch --create BRANCH`. Run later commands in its sibling path.
- **Cleanup**: `wt remove BRANCH` refuses uncommitted changes. Pass `--force` only when the user asks.
