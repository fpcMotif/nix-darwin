# AGENTS.md

Repo-level guidance for coding agents working in this Nix configuration.

## Agent skills

Skill discovery and loading: `skill-router discover`, `skill-router load <scope:id>`, package skills via `bunx @tanstack/intent@0.0.41 load <pkg>#<skill>`. See [docs/agents/skill-router.md](docs/agents/skill-router.md).

### Issue tracker

Issues and PRDs live in GitHub Issues on [fpcMotif/nix-darwin](https://github.com/fpcMotif/nix-darwin/issues), accessed via the `gh` CLI. See [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md).

### Triage labels

Uses the canonical five-role vocabulary unchanged (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See [docs/agents/triage-labels.md](docs/agents/triage-labels.md).

### Domain docs

Single-context — one `GLOSSARY.md` + `docs/adr/` at the repo root. See [docs/agents/domain.md](docs/agents/domain.md).

## HTTP

`ax URL` is the required first choice for every HTTP request, including fetch, discovery, extraction, and API calls. Use `curl` only when `ax` cannot support the required operation or has a concrete failure; state that reason.

## Code Mode & programmatic execution

Use Code Mode (`eval` with Bun/JS or Python in OMP, or compound programmatic scripts) for multi-step inspection and operations:
- **Bulk inspection**: Gather all relevant repository status, diffs, bookmarks, and open PRs in one pass (`Promise.all` or compound commands) instead of ping-ponging individual tools across turns.
- **Single-flight actions**: Execute multi-step operations in 1–2 dense invocations. Parse and filter data in-memory; do not spend agent turns on intermediate terminal output.
- **Deterministic VCS**: For committing, opening PRs, and landing on main, run in a single flight:
  ```bash
  bun run scripts/jj-ship.ts ship -n <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land
  ```
  `jj-ship.ts` runs the checkout's `modules/home/jj-pr/jj-pr.sh`, so it works before a rebuild. The installed `jj pr` takes `-m` and `--land` only after `darwin-rebuild switch` installs that script. Check `jj pr --help` before you call it with those flags.
