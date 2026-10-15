---
paths:
  - "!**/*.md"
when:
  - "(^|\\s)(#|//|/\\*)"
---
# Comments Explain Why

A comment exists only to state WHY: a reason the code and its names cannot show. Valid reasons are an external bug or quirk, a platform constraint, an invariant the code relies on, a measured number, a rejected alternative, or an issue/ADR reference. Test: delete the comment. If a careful reader loses no reason, it must go.

Flag any comment that:
- Says what the code does or how it works, even when phrased as a reason ("so that X" where X is the next line's effect).
- Could be replaced by a better name, a named function, or a type. Flag it as "rename instead".
- Labels a section, a banner, a step number, or a function signature (`# label want got`).
- Records history: dates, `once`, `used to`, `no longer`, `was`, `retired`, incident stories.
- States something false or stale about the code it sits on.
- Spans more than three lines, or sits apart from the line it explains.
- Uses hedging (`should`, `may`, `probably`), filler, semicolons, or em-dashes.

Exempt: functional directives (shebang, `# shellcheck`, `# /// script`, build tags, pragmas), text the program prints as usage or help, and `#` lines inside a heredoc or string the program writes out (generated config, fixtures, test data).
