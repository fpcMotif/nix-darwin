# code-review is the review host; routing lives in CLAUDE.md, not in a router skill

Status: accepted (2026-09-09)

## Context

An architecture pass over the git, GitHub, jj, and review skills (2026-09-09) found four proactive claimants for "review this" and PR URLs: the dotfiles-pi `review` (git-only, reimplementing `gh` without better-github-skill's gotchas), mattpocock `code-review`, the `/code-review` plugin command (posts `gh pr comment`), and ripwire-change-check. None named another, CLAUDE.md's "review before commit" routed to none, and every one hardcoded git while the jj skill forbade all git, so nothing composed in a colocated repo. The candidate fix was a vendored local `review` router (the jj precedent, ADR-0008).

## Decision

1. mattpocock `code-review` is the **review host** (CONTEXT.md), installed verbatim through the Claude plugin. It is not forked, transformed, or changed upstream: it arrives as a plugin, so a change there is a plugin bump, not a repo edit.
2. The dotfiles-pi `review` is retired from `skills.explicit`. The plugin `/code-review` command stays as the only posting path, user-invoked only.
3. Routing lives in the Git section of CLAUDE.md, one line per branch: jj first, the review host and its fixed point, better-github-skill for reads, diff shape before lines, hunk for human review. The jj skill carries the command tables and the **colocated contract** (CONTEXT.md). No router skill.
4. The host reads committed history (`git diff <point>...HEAD`), so the rule is commit first (`jj new` in jj); the still-open change goes through ripwire-change-check. The default fixed point is trunk (`main`).
5. The settings seed drops the seven plugins no machine has installed (`ralph-loop` and the six `frad-dotclaude` entries), so a fresh machine matches this one.

## Consequences

- One proactive review skill; the hygiene lists do not change (no new vendored id).
- CLAUDE.md pays one line per branch; the hunk and jj command duplicates leave it.
- ADR-0009's remaining example of a per-skill CLI-deps list (`review`) is gone; `skills.explicit` keeps `web-browser` and the pstack entries.
- Known gap left in the host: its description promises work-in-progress review while its diff excludes the working tree (verified 2026-09-09 on this repo; upstream mattpocock/skills #511 and #958 track it). The commit-first rule covers it here.
- The `frad-dotclaude` marketplace registration stays; it now enables nothing.

## What would change this decision

- The host gaining a working-tree mode or jj awareness upstream: the commit-first line in CLAUDE.md goes.
- A second real review host (another plugin claiming the same triggers): revisit the router, since routing by one CLAUDE.md line stops scaling past one host.
- The plugin surface disappearing (mattpocock skills only as a flake input): the transformed-skill pattern (ADR-0014) becomes available and "installed verbatim" can be reconsidered.
