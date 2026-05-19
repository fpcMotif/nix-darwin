# CLAUDE.md

Repo-level guidance for Claude Code working in this Nix configuration.

## Agent skills

### Issue tracker

Issues and PRDs live in GitHub Issues on [fpcMotif/nix-darwin](https://github.com/fpcMotif/nix-darwin/issues), accessed via the `gh` CLI. See [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md).

### Triage labels

Uses the canonical five-role vocabulary unchanged (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See [docs/agents/triage-labels.md](docs/agents/triage-labels.md).

### Domain docs

Single-context — one `CONTEXT.md` + `docs/adr/` at the repo root (created lazily by `/grill-with-docs`). See [docs/agents/domain.md](docs/agents/domain.md).
