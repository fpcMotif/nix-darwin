## Review and cleanup

One default per request. A default fires on its situation. A named-only route runs only when the user names it. Never auto-commit to make an uncommitted change reviewable. Offer the open-change route instead. Commit only when the user asks (`jj new` in a jj repo).

| Request | Default |
| --- | --- |
| Review a committed branch or PR | `code-review`; fixed point `main`, or the PR base |
| Check the open, uncommitted change | `ripwire-change-check` |
| Clean up code | `clean` |
| Simplify code | `simplify`, only when the user says "simplify" |
| Clean up supplied prose (docs, commit messages, PR bodies) | `unslop` |
| Interface review (`interface-review`); a native reviewer (`codex review`, Amp's review command, a standalone OMP `reviewer`); `omp cleanse` | Only when named |

Supporting routes. `better-github-skill` answers PR state, review threads, and CI. Read diff shape before diff lines: a stat first, then path-scoped diffs. `hunk diff --watch` hands review to the user's terminal.

### Review procedure

1. Establish scope: the fixed point (`main` or the PR base) and the revision under review.
2. Inspect diff shape before reading lines.
3. Run `code-review`; keep its Standards and Spec axes.
4. Report each finding with its failure scenario and evidence. Keep unverified suspicions separate.
5. Record the fixed point and the reviewed revision.

### Cleanup procedure

1. Baseline: run the existing quality and check commands (`ripwire-quality-bar` where configured). Record the results.
2. Edit with exactly one editor from the table.
3. Re-run the same checks and inspect the resulting diff.
4. Report pre-existing failures separately from new failures.

Cleanup contract: preserve behavior and public interfaces. Stay within the agreed change. Remove needless code before adding abstractions. Extract shared code only when it is the same responsibility. Do not weaken tests. Do not commit or post. Passing checks is evidence, not proof the rewrite improved the code.

### Posting

`gh pr comment` and `gh pr review` are user-invoked only (ADR-0015). Print the exact command for the user to run. Each host guide names whether its posting guard is a tested command guard or guidance only. `gh api` writes take no prefix guard, so this rule is the only control there.
