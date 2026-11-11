# Plan 003: CI runs `statix` and `deadnix` on every pull request

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e0b6770..HEAD -- .github/workflows/build.yml tests/unit/build-workflow-test.sh`
> If either file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `e0b6770`, 2026-11-10
- **Issue**: https://github.com/fpcMotif/nix-darwin/issues/424

## Why this matters

This repo lints its Nix code with `statix` (antipatterns) and `deadnix`
(dead code). Today the two linters run only from a local pre-commit hook
(`hk.pkl`) and from `just lint`. CI does not run them.

Two kinds of change therefore reach `main` unlinted: the nightly auto-update
pull request, which a workflow opens and merges without a local hook, and any
commit made with the hook bypassed. `ARCHITECTURE.md:366` records the gap as
"CI does not run them yet". After this plan the Linux CI job runs both
linters, and a test fails if the step is removed.

Both linters passed on the working tree on 2026-11-10 (exit 0 each), so the
new step starts green.

## Current state

Files:

- `.github/workflows/build.yml` — the CI workflow. The `flake-check` job
  runs on `ubuntu-latest` and is the job to extend.
- `tests/unit/build-workflow-test.sh` — a shell test that greps the workflow
  text. It is wired as the Nix check `unit-build-workflow` in
  `tests/default.nix:74-78`. Do not edit `tests/default.nix`.
- `justfile:192-194` — the local `lint` recipe. Its two commands are the
  exact commands CI must run:

```just
lint:
    nix develop --command statix check .
    nix develop --command deadnix --fail . --exclude ./references
```

- `flake.nix:195-209` — `devShells.<system>.default` provides `statix` and
  `deadnix` on every supported system, so `nix develop --command` works on
  the Linux runner.
- `statix.toml` — already scopes `statix` away from `references/`.

`.github/workflows/build.yml:42-46` today (the last step of `flake-check`):

```yaml
      - name: Build dev shell and dev container (x86_64-linux)
        run: |
          nix build --no-link --show-trace \
            '.#devShells.x86_64-linux.default' \
            '.#packages.x86_64-linux.dev-container'
```

The next line in the file is blank, then `  darwin:` starts the next job.

The end of `tests/unit/build-workflow-test.sh` today:

```bash
for system in x86_64-linux aarch64-darwin; do
  printf '%s\n' "$code" | grep -F "'.#checks.$system'" | grep -qF 'builtins.attrNames' || {
    echo "build.yml: must enumerate checks.$system with builtins.attrNames" >&2
    exit 1
  }
  printf '%s\n' "$code" | grep -qF ".#checks.$system.%s" || {
    echo "build.yml: must build every enumerated checks.$system name" >&2
    exit 1
  }
done
```

The variable `code` in that script holds the workflow text with comment
lines removed. Reuse it.

Conventions that apply:

- Workflow steps use a `name:` and a `run: |` block, indented as shown above.
- This repo blocks new code comments and Markdown edits outside docs work
  (a `doc-lock` hook). Do not add a YAML comment. Do not edit any `.md` file.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Unit test | `bash tests/unit/build-workflow-test.sh .github/workflows/build.yml` | exit 0, no output |
| Lint baseline | `nix develop --command statix check .` | exit 0, no output |
| Lint baseline | `nix develop --command deadnix --fail . --exclude ./references` | exit 0, no output |
| Nix gate (macOS) | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-build-workflow'` | exit 0 |
| Nix gate (Linux) | `nix build --no-link --print-build-logs '.#checks.x86_64-linux.unit-build-workflow'` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `.github/workflows/build.yml` (add one step to the `flake-check` job)
- `tests/unit/build-workflow-test.sh` (append one block)

**Out of scope** (do NOT touch):

- `.github/workflows/auto-update.yml`. It waits for the `build.yml` checks
  on its pull request, so it inherits the new step.
- The `darwin`, `nixos`, and `nixos-aarch64` jobs. One lint run is enough.
- `hk.pkl`, `justfile`, `statix.toml`, `flake.nix`.
- `ARCHITECTURE.md:366` and the comment at `justfile:189-191`. Both say CI
  does not run the linters. They become stale when this lands. Do not edit
  them. List them in your final report so the maintainer can fix the text.
- Concurrency groups, timeouts, and caching in `build.yml`.
- Fixing lint findings. If the baseline fails, that is a STOP condition.

## Git workflow

- Branch: `advisor/003-ci-runs-nix-lint`.
- One commit. Message style follows the repo, for example
  `feat(just): Warn when a switch puts unlanded commits live`. Use:
  `ci(build): Run statix and deadnix in the Linux check job`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Confirm the lint baseline is green

Run both lint commands from the table.

**Verify**: each exits 0 with no findings printed.

### Step 2: Add the failing test

Append this block to the end of `tests/unit/build-workflow-test.sh`:

```bash

for lint in 'statix check .' 'deadnix --fail . --exclude ./references'; do
  printf '%s\n' "$code" | grep -qF "nix develop --command $lint" || {
    echo "build.yml: must run '$lint' from the repo dev shell" >&2
    exit 1
  }
done
```

**Verify**: `bash tests/unit/build-workflow-test.sh .github/workflows/build.yml`
→ exit 1 with exactly this line on stderr:

```
build.yml: must run 'statix check .' from the repo dev shell
```

### Step 3: Add the lint step to the `flake-check` job

In `.github/workflows/build.yml`, insert the following step directly after
the `Build dev shell and dev container (x86_64-linux)` step and before the
blank line that precedes `  darwin:`. Keep one blank line between steps.

```yaml

      - name: Lint Nix sources (statix, deadnix)
        run: |
          nix develop --command statix check .
          nix develop --command deadnix --fail . --exclude ./references
```

The step goes last in the job so the dev shell is already built.

**Verify**: `bash tests/unit/build-workflow-test.sh .github/workflows/build.yml` → exit 0, no output.
**Verify**: `grep -c "nix develop --command" .github/workflows/build.yml` → `2`.
**Verify**: `git diff --stat -- .github/workflows/build.yml` → `1 file changed, 5 insertions(+)`.

### Step 4: Run the Nix gate

Build the `unit-build-workflow` check for your platform (see "Commands you
will need").

**Verify**: the `nix build` command exits 0.

## Test plan

- The appended block in `tests/unit/build-workflow-test.sh` asserts that the
  workflow runs both linters with the same arguments as `just lint`. Step 2
  proves it fails on the old workflow.
- Structural pattern: the `for system in ...` loop directly above it.
- The workflow itself cannot run locally. Its first real run is the pull
  request that carries this change. A reviewer must confirm the new step is
  green there.

## Done criteria

ALL must hold:

- [ ] `bash tests/unit/build-workflow-test.sh .github/workflows/build.yml` exits 0
- [ ] `grep -c "nix develop --command" .github/workflows/build.yml` returns `2`
- [ ] Both lint commands exit 0 locally
- [ ] The Nix check `unit-build-workflow` builds for the current platform
- [ ] `git status --short` lists only the two in-scope files
- [ ] The final report names the two stale text locations
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Step 1 fails. Report the linter output. Do not fix the findings and do not
  add the CI step on a red baseline.
- The `flake-check` job or its last step does not match the "Current state"
  excerpt.
- Step 2 passes (exit 0) or fails with a different message.
- A hook blocks an edit and names a comment or Markdown change.

## Maintenance notes

- The lint commands now exist in three places: `justfile` (`lint`), `hk.pkl`,
  and `build.yml`. The new test ties `build.yml` to the `just lint` argument
  text. A change to the `deadnix` exclude list must update all three.
- Stale text left for a docs change: `ARCHITECTURE.md:366` ("CI does not run
  them yet") and the comment at `justfile:189-191` ("but CI does not").
- Reviewer: check the first pull-request run. The step adds two flake
  evaluations to the Linux job.
- Deferred: `main` has no branch protection, so nothing forces this check
  before a manual merge. That is a repository setting for the maintainer.
