# AGENTS.md

Repo-level guidance for coding agents working in this Nix configuration.

## Targets and package ownership

- **Targets**: `darwinConfigurations.f` (`aarch64-darwin`, nix-darwin) is the active target. `nixosConfigurations.x230` and `nixosConfigurations.vm-aarch64-utm` are inactive NixOS scaffolds, and `homeConfigurations.martinfan-omakub` is a staged design target with no flake output yet.
- **Pure Nix first**: Package CLI and dev tools in `modules/home/packages.nix` and custom or vendored derivations in `pkgs/` under `pkgs.martin.*` with versioned, immutable URLs. GUI apps with built-in self-updaters or privileged helpers (Dropbox, BetterMouse, BetterDisplay, Google Drive, Raycast) stay GUI-managed outside Nix (ADR-0005, 0011, 0012, 0013). Homebrew stays off by default.
- **Cross-platform purity**: Darwin and Linux hosts share `modules/home/`. Gate macOS-only paths and tools behind `pkgs.stdenv.isDarwin` (ADR-0008).

## Agent skills

Skill discovery and loading: `skill-router discover`, `skill-router load <scope:id>`. See [docs/agents/skill-router.md](docs/agents/skill-router.md).

### Issue tracker

Issues and PRDs live in GitHub Issues on [fpcMotif/nix-darwin](https://github.com/fpcMotif/nix-darwin/issues), accessed via the `gh` CLI. See [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md).

### Triage labels

Uses the canonical five-role vocabulary unchanged (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See [docs/agents/triage-labels.md](docs/agents/triage-labels.md).

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. See [docs/agents/domain.md](docs/agents/domain.md).

## HTTP

`ax URL` is the required first choice for every HTTP request (fetch, discovery, extraction, and API calls). Use `curl` only when `ax` cannot support the required operation or has a concrete failure; state that reason.

## Code Mode & programmatic execution

Use Code Mode (`eval` with Bun/JS or Python in OMP, or compound programmatic scripts) for multi-step inspection and operations:
- **Bulk inspection**: Gather repository status, diffs, bookmarks, and open PRs in one pass (`Promise.all` or compound commands). Do not ping-pong tools across turns.
- **Single-flight actions**: Execute multi-step operations in one or two dense invocations. Parse and filter data in-memory; do not spend agent turns on intermediate terminal output.
- **Deterministic VCS**: To commit, open a PR, and land on main, run in a single flight:
  ```bash
  nix run .#martin.jj-pr -- <name> -m "type(scope): msg" -t "PR title" -F /path/to/body.md --land -- <paths>
  ```
  `nix run .#martin.jj-pr` builds the checkout's `jj pr`, so it works before a rebuild. Paths after the final `--` limit the commit to those paths and leave the rest in `@`. Omit them to commit all of `@`. `--land` moves edits left in `@` onto `main`.
