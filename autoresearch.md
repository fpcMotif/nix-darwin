# Autoresearch: Nix code quality, readability, and documentation

## Objective
Improve this Nix configuration's maintainability without changing user-visible behavior. Optimize for Nix best practices, readable module layout, documented architecture, and trustworthy checks. The active target is `darwinConfigurations.f`; Linux/NixOS scaffolds must keep evaluating.

This session runs in the isolated worktree:

`/tmp/nix-config-autoresearch`

The original checkout had unrelated uncommitted changes when this session started; do not touch or depend on them.

## Metrics
- **Primary**: `quality_debt` (points, lower is better) — objective maintainability debt from repository-local signals.
- **Secondary**:
  - `docs_missing_modules`: source modules under `modules/` not named in `ARCHITECTURE.md`.
  - `docs_missing_tests`: test files or test attributes not named in `tests/README.md`.
  - `docs_stale_tests`: test names documented in `tests/README.md` that are not check attributes.
  - `lint_contract_gaps`: documented lint tools that are not actually wired into tests.
  - `long_nix_lines`: Nix source lines over 140 chars, excluding generated/reference/local worktree paths.
  - `nix_files`: count of measured Nix files.

`quality_debt = docs_missing_modules * 10 + docs_missing_tests * 8 + docs_stale_tests * 8 + lint_contract_gaps * 25 + long_nix_lines`.

The metric is a guide, not permission to game the benchmark. Do not delete useful code or documentation solely to reduce counts. Improvements should make a human reviewer happier and should keep checks passing.

## How to Run
`./autoresearch.sh`

It prints `METRIC name=value` lines for pi-autoresearch. `autoresearch.checks.sh` runs the correctness gate after successful metric runs.

## Files in Scope
- `ARCHITECTURE.md` — architecture and module-layout documentation.
- `CONTEXT.md` — glossary only; update only when terminology is clarified.
- `tests/README.md` — test-suite documentation.
- `tests/default.nix`, `tests/unit/*.nix`, `tests/lib/*.nix`, `tests/integration/*.nix` — quality gates and assertions.
- `hosts/**/*.nix`, `modules/**/*.nix`, `lib/**/*.nix`, `pkgs/**/*.nix` — source refactors when they improve readability without behavior drift.
- `.github/workflows/*.yml` — only if check wiring/docs require it.

## Off Limits
- `references/` sample repositories.
- Secrets, personal tokens, machine-local state, and generated build outputs.
- The original checkout's unrelated dirty work.
- Flake input updates unless the experiment explicitly targets dependency freshness.

## Constraints
- Prefer small, reviewable Nix changes.
- Keep the flake root thin; feature behavior belongs in `hosts/`, `modules/`, `lib/`, or `pkgs/`.
- Active Mac target `darwinConfigurations.f` has priority.
- `nixpkgs-fmt` formatting must pass.
- Static lint additions must be real checks, not metric-only checks.
- Documentation must describe source-of-truth behavior, not aspirational behavior.
- Be adversarial: after each kept change, inspect whether the metric could have improved while maintainability got worse; if yes, fix the metric or discard the idea.

## What's Been Tried
- Baseline `quality_debt=308`: module/test documentation drift and lint-contract gaps dominated.
- Kept: refreshed `ARCHITECTURE.md` module inventory so Darwin/Home module docs match current imports (`quality_debt=98`).
- Kept: synchronized `tests/README.md` with actual `tests/default.nix` check attributes (`quality_debt=74`).
- Tried and reverted: adding a real statix/deadnix check. It found real statix warnings; do not re-add the gate until those warnings are fixed or intentionally scoped.
- Tooling blockers: `openai/gpt-5.3-codex-spark` subagent calls fail because this pi environment has no OpenAI API key; Parallel.ai `deep_research` fails because the account has insufficient credit. Use available subagents plus DeepWiki/public docs until auth/credit changes.
