# Autoresearch: Nix code quality, readability, and documentation

## Objective
Improve this Nix configuration's maintainability without changing user-visible behavior. Optimize for Nix best practices, readable module layout, documented architecture, and trustworthy checks. The active target is `darwinConfigurations.f`; Linux/NixOS scaffolds must keep evaluating.

This session runs in the isolated worktree:

`/tmp/nix-config-autoresearch`

The original checkout had unrelated uncommitted changes when this session started; do not touch or depend on them.

## Metrics
- **Primary**: `loop_guidance_debt` (points, lower is better) — prompt/goal/search/experiment guidance debt for safe resumed autoresearch.
- **Secondary**:
  - `doc_truth_debt`: documentation/check truthfulness debt from repository-local signals.
  - `quality_debt`: the previous saturated module/test/lint/line-length metric.
  - `docs_missing_modules`: source modules under `modules/` not named in `ARCHITECTURE.md`.
  - `docs_missing_tests`: test files or test attributes not named in `tests/README.md`.
  - `docs_stale_tests`: test names documented in `tests/README.md` that are not check attributes.
  - `lint_contract_gaps`: documented lint tools that are not actually wired into tests.
  - `long_nix_lines`: Nix source lines over 140 chars, excluding generated/reference/local worktree paths.
  - `stale_linting_policy`: `ARCHITECTURE.md` still says statix/deadnix are not enforced even though they are.
  - `missing_statix_policy_doc`: `statix.toml` exists but `ARCHITECTURE.md` does not describe the local policy.
  - `stale_review_date`: `ARCHITECTURE.md` Last reviewed date is not the current session date.
  - `guidance_missing_sections`: required autoresearch guidance sections are missing.
  - `guidance_empty_sections`: required autoresearch guidance sections exist but have no body.
  - `nix_files`: count of measured Nix files.

`doc_truth_debt = quality_debt + stale_linting_policy * 25 + missing_statix_policy_doc * 15 + stale_review_date * 10`.
`loop_guidance_debt = doc_truth_debt + guidance_missing_sections * 10 + guidance_empty_sections * 5`.

The metric is a guide, not permission to game the benchmark. Do not delete useful code or documentation solely to reduce counts. Improvements should make a human reviewer happier and should keep checks passing.

## How to Run
`./autoresearch.sh`

It prints `METRIC name=value` lines for pi-autoresearch. `autoresearch.checks.sh` runs the correctness gate after successful metric runs. The previous `doc_truth_debt` and `quality_debt` metrics are still emitted as secondary monitors.

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
- Kept: wrapped long Nix source lines with named constants/string concatenation while preserving behavior (`quality_debt=51`).
- Kept: added a real `unit-static-lint` gate for `statix` + `deadnix`, fixed actionable lint findings, and documented the narrow `repeated_keys` statix opt-out (`quality_debt=1`).
- Kept: wrapped the final long BetterMouse assertion message (`quality_debt=0`).
- Previous primary metric reached its lower bound (`quality_debt=0`). Reinitialized around `doc_truth_debt` to catch stale source-of-truth docs and policy drift without weakening checks. Baseline `doc_truth_debt=10` showed only the `ARCHITECTURE.md` review date was stale after the doc was re-read.
- `doc_truth_debt` then reached its lower bound (`0`). User asked to recursively improve the prompt, goal, search goal, experiments, beliefs, hypotheses, and assumptions. Reinitialize around `loop_guidance_debt` so the persisted prompt guides future agents realistically instead of chasing saturated metrics.
- Tooling blockers: `openai/gpt-5.3-codex-spark` subagent calls fail because this pi environment has no OpenAI API key; Parallel.ai `deep_research` fails because the account has insufficient credit. Use available subagents plus DeepWiki/public docs until auth/credit changes.
