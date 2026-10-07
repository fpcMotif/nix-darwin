## Docs lock

Comments and Markdown change only in docs work. Docs work is a request that names it: an ADR, CONTEXT.md, a README, docs, comments, or `setup-matt-pocock-skills`.

- **Comments**: Keep existing comments as written. Carry intent in names, types, and tests. A comment leaves only with the code it describes.
- **Suppressions**: Fix the lint or type error. A suppression such as `@ts-expect-error`, `eslint-disable`, or `noqa` is a comment.
- **Directives**: A functional directive is code, not a comment. The list: a shebang, a `# /// script` block, `//go:build`, `/// <reference>`, an `@vitest-environment`, `@jest-environment`, or JSX pragma, an encoding cookie, `# frozen_string_literal`, and `// swift-tools-version`.
- **Restore**: A comment this session removed may come back. The check compares against the file as the session first edited it.
- **Markdown**: Keep Markdown files as they are. Put what a doc should say in your reply.
- **Stale text**: Report a stale comment or doc in your reply. Outside docs work, this narrows Reconcile and Present.
- **Strip**: `doc-lock strip FILE...` deletes the comments each named file gained since HEAD. Name only files you changed.
- **Lock**: Claude Code, Codex, pi, and omp run `doc-lock` before every edit, and it blocks these changes until a docs request opens it for the session. In a repository with `hk.pkl`, the `doc-lock` pre-commit step blocks them at commit.
