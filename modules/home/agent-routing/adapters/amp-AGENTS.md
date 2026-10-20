# AGENTS.md — Amp

Amp includes this file in every session. It points at the shared rules instead of
copying them, so the shared block renders exactly once across guide locations.

- **Develop**: Before choosing a shell command, running Python, or using version control, read `~/.config/agent-guidance/development.md`. Its Review and cleanup section names the default for each request.
- **Posting**: Guidance only. No command-scoped posting guard is wired for Amp and `amp.dangerouslyAllowAll` is on, so never run `gh pr comment` or `gh pr review` unless the user explicitly asked; print the command for the user to run.
