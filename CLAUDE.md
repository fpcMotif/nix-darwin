# CLAUDE.md

Repo-level guidance for Claude Code working in this Nix configuration.

## Agent skills

Skill discovery and loading: `skill-router discover`, `skill-router load <scope:id>`, package skills via `bunx @tanstack/intent@0.0.41 load <pkg>#<skill>`. See [docs/agents/skill-router.md](docs/agents/skill-router.md).

### Issue tracker

Issues and PRDs live in GitHub Issues on [fpcMotif/nix-darwin](https://github.com/fpcMotif/nix-darwin/issues), accessed via the `gh` CLI. See [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md).

### Triage labels

Uses the canonical five-role vocabulary unchanged (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See [docs/agents/triage-labels.md](docs/agents/triage-labels.md).

### Domain docs

Single-context — one `CONTEXT.md` + `docs/adr/` at the repo root. See [docs/agents/domain.md](docs/agents/domain.md).
