# Autoresearch: Nix code quality, readability, and documentation

## Objective
Improve this Nix configuration's maintainability without changing user-visible behavior. Optimize for Nix best practices, readable module layout, documented architecture, and trustworthy checks. The active target is `darwinConfigurations.f`; Linux/NixOS scaffolds must keep evaluating.

This session runs in the isolated worktree:

`/tmp/nix-config-autoresearch`

The original checkout had unrelated uncommitted changes when this session started; do not touch or depend on them.

## Metrics
- **Primary**: `claude_activation_locality_debt` (points, lower is better) — Claude activation logic still embedded in the large skills/files module instead of a tested focused submodule.
- **Secondary**:
  - `agent_docs_truth_debt`: stale Agent Skills architecture claims after Claude activation coverage changes.
  - `claude_activation_coverage_debt`: missing behavioral assertions for the large Claude Home Manager module's managed files and activation scripts.
  - `activation_path_literal_debt`: duplicated activation path literals in high-risk Darwin modules, after behavioral coverage is in place.
  - `behavioral_coverage_debt`: behavioral integration assertion debt for high-risk active custom modules.
  - `check_parity_debt`: drift between test definitions, local recipes, CI, and the autoresearch correctness gate.
  - `option_doc_debt`: custom Nix option documentation debt.
  - `loop_guidance_debt`: prompt/goal/search/experiment guidance debt for safe resumed autoresearch.
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
  - `option_total`: `lib.mkOption` declarations under `modules/`.
  - `option_missing_descriptions`: `lib.mkOption` declarations without a `description` field.
  - `option_missing_examples`: `lib.mkOption` declarations without an `example` field.
  - `just_check_missing_test_attrs`: check attributes in `tests/default.nix` not covered by `just check` unless it delegates to `nix flake check`.
  - `autoresearch_missing_focused_checks`: unit/integration check attributes missing from `autoresearch.checks.sh`.
  - `just_check_missing_darwin_build`: whether `just check` misses the active `darwinConfigurations.f.system` build.
  - `ci_missing_flake_check`: whether CI is missing `nix flake check`.
  - `ci_missing_system_builds`: expected system configuration builds missing from CI.
  - `missing_behavioral_assertions`: required integration assertions missing for active high-risk modules with activation scripts or generated config.
  - `required_behavioral_assertions`: count of required high-risk behavioral assertions.
  - `activation_path_duplicate_literals`: repeated high-risk activation path literals in `modules/darwin/rime.nix` and `modules/darwin/mouse-display.nix` beyond one source-of-truth occurrence.
  - `missing_claude_activation_assertions`: required integration assertions missing for `modules/home/claude.nix` managed files and activation scripts.
  - `required_claude_activation_assertions`: count of required Claude activation/file assertions.
  - `stale_agent_skills_activation_claim`: `ARCHITECTURE.md` still claims Claude has no custom activation scripts even though `modules/home/claude.nix` does.
  - `claude_main_activation_blocks`: Claude-specific `home.activation.*` blocks still present in `modules/home/claude.nix`.
  - `missing_claude_split_modules`: required focused Claude support modules (`claude-common.nix`, `claude-activations.nix`) missing.
  - `nix_files`: count of measured Nix files.

`doc_truth_debt = quality_debt + stale_linting_policy * 25 + missing_statix_policy_doc * 15 + stale_review_date * 10`.
`loop_guidance_debt = doc_truth_debt + guidance_missing_sections * 10 + guidance_empty_sections * 5`.
`option_doc_debt = loop_guidance_debt + option_missing_descriptions * 10 + option_missing_examples * 2`.
`check_parity_debt = option_doc_debt + just_check_missing_test_attrs * 3 + autoresearch_missing_focused_checks * 8 + just_check_missing_darwin_build * 10 + ci_missing_flake_check * 20 + ci_missing_system_builds * 10`.
`behavioral_coverage_debt = check_parity_debt + missing_behavioral_assertions * 5`.
`activation_path_literal_debt = behavioral_coverage_debt + activation_path_duplicate_literals * 4`.
`claude_activation_coverage_debt = activation_path_literal_debt + missing_claude_activation_assertions * 5`.
`agent_docs_truth_debt = claude_activation_coverage_debt + stale_agent_skills_activation_claim * 15`.
`claude_activation_locality_debt = agent_docs_truth_debt + claude_main_activation_blocks * 5 + missing_claude_split_modules * 5`.

The metric is a guide, not permission to game the benchmark. Do not delete useful code or documentation solely to reduce counts. Improvements should make a human reviewer happier and should keep checks passing.

## How to Run
`./autoresearch.sh`

It prints `METRIC name=value` lines for pi-autoresearch. `autoresearch.checks.sh` runs the correctness gate after successful metric runs. The previous `agent_docs_truth_debt`, `claude_activation_coverage_debt`, `activation_path_literal_debt`, `behavioral_coverage_debt`, `check_parity_debt`, `option_doc_debt`, `loop_guidance_debt`, `doc_truth_debt`, and `quality_debt` metrics are still emitted as secondary monitors.

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

## Current Beliefs
- The original quality signals were useful but are now saturated; further real improvement needs broader targets or better loop guidance, not negative debt.
- The highest-value near-term work is improving source-of-truth documentation, check coverage, and module navigability while keeping the active Mac target stable.
- Small Nix changes beat broad rewrites in this repo because `darwinConfigurations.f` is personal production infrastructure.
- A metric is a steering aid, not the goal. If a metric rewards a change that would confuse a maintainer, discard the change and revise the metric.

## Assumptions to Re-check
- `ARCHITECTURE.md` still matches actual flake/module behavior after each structural change.
- The `statix` `repeated_keys` opt-out remains justified; if modules become harder to scan, revisit it.
- `autoresearch.checks.sh` is representative enough for fast iteration, even though full CI also covers Linux and system builds.
- Worktree state may be pruned by tooling; verify `pwd`, branch, and `git status` before each experiment.
- RLM/subagent availability is not guaranteed; use them opportunistically, and record blockers instead of pretending recursive review happened.

## Search Goals
- Find stale documentation claims after code changes, especially in `ARCHITECTURE.md`, `tests/README.md`, and `CLAUDE.md`.
- Look for custom module options without clear descriptions, defaults, or tests.
- Compare CI coverage, local `just` recipes, and `autoresearch.checks.sh` for drift.
- Search for shallow modules or duplicated activation patterns where a small helper would improve locality without adding speculative seams.
- Revisit reference repos only for patterns; never import or lint them as active source.

## Hypotheses Backlog
- A metric for option-documentation coverage may reveal real maintainability debt in custom `martin.*` modules.
- A check-parity metric may catch drift between `tests/default.nix`, `.github/workflows/build.yml`, `justfile`, and `autoresearch.checks.sh`.
- Some repeated Home Manager activation patterns may be deepened behind small helper functions, but only if at least two call sites become clearer.
- `modules/home/claude.nix` is large; a focused split may improve locality, but only if tests and docs make ownership clearer.
- The static-lint gate may be expanded later if a rule can be enabled without fighting intentional Home Manager style.

## Experiment Queue
1. Baseline `claude_activation_locality_debt` after docs and tests establish the Claude activation boundary.
2. Move Claude-specific activation scripts into `modules/home/claude-activations.nix` and shared skill constants into `modules/home/claude-common.nix`, imported by the existing Claude module.
3. Keep `modules/home/claude.nix` as the orchestrating module for managed files and `programs.agent-skills`; do not split every helper just to reduce line count.
4. If another code refactor is attempted, characterize behavior through existing checks first, then make the smallest source change possible.

## Recursive/Delegated Review Plan
- Try RLM for goal and hypothesis review when the tool is healthy; current attempts failed with path/certificate errors, so do not depend on it.
- If RLM is unavailable, use available `reviewer`, `planner`, or `oracle` subagents for read-only critique before broad metric changes.
- Use DeepWiki for Nix/Home Manager upstream behavior when local assumptions touch library semantics.
- Capture recursive-review blockers in ASI so future iterations know whether a missing review was a tool problem or a deliberate skip.

## Realism Guardrails
- Never weaken tests, remove useful docs, or exclude active files just to improve a metric.
- When a primary metric reaches zero, reinitialize around a broader real quality target instead of inventing negative debt.
- Keep every kept change reviewable on its own: one hypothesis, one small diff, one clear verification path.
- Prefer discarding unchanged runs over keeping process-only churn unless the process artifact materially helps future agents.
- Treat the active Mac config as production; avoid risky evaluation or activation semantics for cosmetic wins.

## What's Been Tried
- Baseline `quality_debt=308`: module/test documentation drift and lint-contract gaps dominated.
- Kept: refreshed `ARCHITECTURE.md` module inventory so Darwin/Home module docs match current imports (`quality_debt=98`).
- Kept: synchronized `tests/README.md` with actual `tests/default.nix` check attributes (`quality_debt=74`).
- Kept: wrapped long Nix source lines with named constants/string concatenation while preserving behavior (`quality_debt=51`).
- Kept: added a real `unit-static-lint` gate for `statix` + `deadnix`, fixed actionable lint findings, and documented the narrow `repeated_keys` statix opt-out (`quality_debt=1`).
- Kept: wrapped the final long BetterMouse assertion message (`quality_debt=0`).
- Previous primary metric reached its lower bound (`quality_debt=0`). Reinitialized around `doc_truth_debt` to catch stale source-of-truth docs and policy drift without weakening checks. Baseline `doc_truth_debt=10` showed only the `ARCHITECTURE.md` review date was stale after the doc was re-read.
- `doc_truth_debt` then reached its lower bound (`0`). User asked to recursively improve the prompt, goal, search goal, experiments, beliefs, hypotheses, and assumptions. Reinitialized around `loop_guidance_debt` so the persisted prompt guides future agents realistically instead of chasing saturated metrics.
- `loop_guidance_debt` reached its lower bound (`0`). Reinitialized around `option_doc_debt` to test the backlog hypothesis that custom option examples expose real documentation debt in Nix modules.
- `option_doc_debt` reached its lower bound (`0`) after adding realistic examples to every custom `lib.mkOption` declaration.
- Reinitialized around `check_parity_debt` to test the backlog hypothesis that local recipes, CI, and the autoresearch correctness gate may drift from the real check set. The valid baseline found `just check` was a stale manual subset while CI and the focused autoresearch gate were aligned with their contracts.
- Kept: make `just check` delegate to `nix flake check --show-trace --print-build-logs` before building `darwinConfigurations.f.system`, so the developer-facing local recipe matches its full-check-suite contract without duplicating check attr names (`check_parity_debt=0`).
- Reinitialized around `behavioral_coverage_debt` to cover active high-risk custom modules with activation scripts or generated config. Baseline found missing assertions for Rime activation, Ghostty generated config/theme output, and BetterMouse seed/launchd behavior.
- Kept: added real integration assertions for Rime enablement/package/postActivation/user activation, Ghostty generated config/custom theme file, and BetterMouse seed activation/launchd agents (`behavioral_coverage_debt=0`).
- Reinitialized around `activation_path_literal_debt` to simplify duplicated high-risk activation paths in Rime and BetterMouse now that behavior is covered by tests.
- Kept: factored repeated BetterMouse Application Support, Rime user config, and Squirrel input-method paths into named constants (`activation_path_literal_debt=0`).
- Reinitialized around `claude_activation_coverage_debt` to characterize the large Claude Home Manager module before any future split/refactor.
- Kept: added integration assertions for Claude managed files, settings seed, Stop-hook debug wrapping, disabled grill-me cleanup, and superpowers plugin brainstorming parking (`claude_activation_coverage_debt=0`).
- Reinitialized around `agent_docs_truth_debt` after the new assertions exposed a stale `ARCHITECTURE.md` claim that `modules/home/claude.nix` has no custom activation scripts. Baseline found only that stale Agent Skills mechanism sentence.
- Kept: refreshed the Agent Skills mechanism docs to distinguish upstream DSL-managed skill bundles from adjacent Claude activation scripts for settings seeding, Stop-hook diagnostics, and duplicate-skill cleanup (`agent_docs_truth_debt=0`).
- Reinitialized around `claude_activation_locality_debt` to split tested Claude activation logic out of the large skill/file module without changing behavior.
- Tooling blockers: `openai/gpt-5.3-codex-spark` subagent calls fail because this pi environment has no OpenAI API key; Parallel.ai `deep_research` fails because the account has insufficient credit. Use available subagents plus DeepWiki/public docs until auth/credit changes.
