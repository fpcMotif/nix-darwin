# code-review is the review host; routing lives in CLAUDE.md, not in a router skill

Status: accepted

Three skills previously competed for "review this" and PR review triggers: `dotfiles-pi` `review` (Git-only), `mattpocock` `code-review`, and `/code-review`. None coordinated with the others or with Jujutsu's colocated Git repository. We made `mattpocock` `code-review` the single proactive **Review host** and retired `dotfiles-pi` `review`. We kept `/code-review` for explicit user-invoked PR comments, and placed review routing in the development guide and `jj` skill (**Colocated contract**).

## Considered options

- **Keep both `dotfiles-pi` `review` and `mattpocock` `code-review` enabled.** Rejected: overlapping triggers make skill selection non-deterministic and duplicate GitHub CLI instructions.
- **Write a local vendored `review-router` skill.** Rejected: adds another skill to the catalog when a few lines in the development guide route `code-review`, `better-github-skill`, and `hunk` directly.
- **Fork or transform `mattpocock` `code-review` to add JJ commands.** Rejected: because `git HEAD` equals `@-` in a colocated JJ repo, `code-review`'s `git diff <base>...HEAD` works after `jj commit` or `jj new`.

## Consequences and trade-offs

- Because `code-review` diffs committed Git history (`<base>...HEAD`), the user or agent must commit or run `jj new` before reviewing working-copy edits.
- Review tool composition (`code-review` + `better-github-skill` + `hunk`) relies on agents reading the development guide's version-control section.
- **Reversal trigger:** Introduce a router skill if a second proactive review skill lands; drop the commit-first rule if upstream `code-review` adds JJ support.
