## Parallel checkouts

- **Git**: Create a parallel Git checkout with `wt switch --create BRANCH`. It prints the new sibling path; run later commands there.
- **Cleanup**: `wt remove BRANCH` refuses uncommitted changes. Pass `--force` only when the user asks.
