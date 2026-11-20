# Plan 005: The nightly auto-update PR title and body name the bump mode that actually ran

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- .github/workflows/auto-update.yml tests/unit/auto-update-test.sh scripts/lib/auto-update.sh`
> If any of these files changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. Plan 004
> edits the test file, and that change is expected. Any other mismatch is a
> STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/004-fff-mcp-updater-follows-pinned-nightly.md (same test file, land in order)
- **Category**: bug
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

The nightly workflow compares the bump mode to the word `heavy`, but the
library only ever prints `full` or `light`. So every nightly PR is labelled
"light", including the weekly one that bumps nixpkgs. This plan changes the two
comparisons to `full` and adds a test that ties the workflow's literals to the
library's output. The cadence policy and the updater run are unchanged.

## Why this matters

A reviewer reads the PR title to judge diff size and CI length. On the weekly
nixpkgs day the title says "light — heavy inputs deferred" and the body says
"small diff by construction". The PR actually rebuilds the whole closure. The
label tells the reviewer the opposite of the truth.

## Current state

Files:

- `scripts/lib/auto-update.sh` — shared updater library. `au_bump_mode` lives here. Not edited.
- `.github/workflows/auto-update.yml` — the nightly workflow. Holds the wrong literal.
- `tests/unit/auto-update-test.sh` — shell test, Nix check `unit-auto-update`.
  Its fifth argument is the `.github` directory, stored in `github_dir`.

`scripts/lib/auto-update.sh:58-67` today:

```bash
# Comparing weekdays here would copy the cadence policy out of au_inputs_to_bump.
au_bump_mode() {
  local day=$1 heavy_inputs
  read -ra heavy_inputs <<<"$AU_HEAVY_INPUTS"
  if [ -n "$(au_inputs_to_bump "$day" "${heavy_inputs[@]}")" ]; then
    printf 'full\n'
  else
    printf 'light\n'
  fi
}
```

`.github/workflows/auto-update.yml:63-65` stores that output:

```yaml
          mode=$(AU_FORCE_FULL_BUMP=${FORCE_FULL_BUMP:-0} \
            bash scripts/lib/auto-update.sh bump-mode)
          echo "AU_BUMP_MODE=$mode" >> "$GITHUB_ENV"
```

`.github/workflows/auto-update.yml:105` today:

```yaml
          title: "auto-update: nightly bump (${{ env.AU_BUMP_MODE == 'heavy' && 'heavy — includes nixpkgs' || 'light — heavy inputs deferred' }})"
```

`.github/workflows/auto-update.yml:110` today starts with:

```yaml
            **Run mode: ${{ env.AU_BUMP_MODE }}**${{ env.AU_BUMP_MODE == 'heavy' && ' — includes nixpkgs; expect a large diff and a long CI run.' || ' — the heavy input (nixpkgs) deferred ...
```

`tests/unit/auto-update-test.sh:125-130` already pins the library output:

```bash
mode=$(au_bump_mode "$AU_CADENCE_DAY")
[ "$mode" = "full" ] || fail "expected 'full' on cadence day, got '$mode'"
mode=$(au_bump_mode "$other_day")
[ "$mode" = "light" ] || fail "expected 'light' off cadence day, got '$mode'"
```

The test file has this block near its end. Add to it, do not replace it:

```bash
if [ -n "$github_dir" ]; then
  # build.yml builds every check by name enumeration
  # (tests/unit/build-workflow-test.sh), so only the nightly workflow names it.
  grep -qF 'unit-auto-update' "$github_dir/workflows/auto-update.yml" \
    || fail "auto-update.yml does not run the unit-auto-update check"
```

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work. Add no comments.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Unit test, direct | `bash tests/unit/auto-update-test.sh scripts/lib/auto-update.sh modules/darwin/auto-switch.nix pkgs scripts .github` | last line `auto-update-test: all assertions passed` |
| Nix gate | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update'` | exit 0 |
| Literal scan | `rg -n "AU_BUMP_MODE == '" .github/workflows/auto-update.yml` | two lines, both with `'full'` |

## Scope

**In scope** (the only files you may modify):

- `.github/workflows/auto-update.yml` (lines 105 and 110 only)
- `tests/unit/auto-update-test.sh` (insert one block)

**Out of scope** (do NOT touch):

- `scripts/lib/auto-update.sh`. The names `full` and `light` are tested and
  used by `scripts/update-flake-inputs.sh`. Do not rename them.
- The "Clean stray sed/sed-bak artifacts" step at workflow lines 78-83. It
  deletes `.bak` files before the guard that checks for them. That is a known
  oddity, deferred on purpose.
- The hand-written package list in the PR body at lines 112-118.
- `.github/workflows/build.yml`. Issue #433 and plan 003 own it.

## Git workflow

- Branch: `advisor/005-nightly-pr-title-names-the-real-bump-mode`.
- One commit: `fix(ci): label the nightly PR with the bump mode that ran`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Add the failing test

In `tests/unit/auto-update-test.sh`, find the line
`if [ -n "$github_dir" ]; then` near the end of the file. Insert this block
directly after the `|| fail "auto-update.yml does not run the unit-auto-update check"` line:

```bash
  while IFS= read -r literal; do
    case "$literal" in
      full|light) ;;
      *) fail "auto-update.yml compares AU_BUMP_MODE to '$literal', which au_bump_mode never prints" ;;
    esac
  done < <(grep -oE "AU_BUMP_MODE == '[^']+'" "$github_dir/workflows/auto-update.yml" | cut -d"'" -f2)
```

**Verify**: run the direct unit test command. It must FAIL with
`auto-update.yml compares AU_BUMP_MODE to 'heavy', which au_bump_mode never prints`.

### Step 2: Fix the two comparisons

In `.github/workflows/auto-update.yml`:

- Line 105: change `env.AU_BUMP_MODE == 'heavy' && 'heavy — includes nixpkgs'`
  to `env.AU_BUMP_MODE == 'full' && 'full — includes nixpkgs'`.
- Line 110: change `env.AU_BUMP_MODE == 'heavy' &&` to `env.AU_BUMP_MODE == 'full' &&`.

Change nothing else on either line.

**Verify**: `rg -n "AU_BUMP_MODE == '" .github/workflows/auto-update.yml` prints
exactly two lines and both contain `'full'`. `rg -n "'heavy'" .github/workflows/auto-update.yml` prints nothing.

### Step 3: Run the tests

**Verify**: the direct unit test command ends with `all assertions passed`.
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update'` exits 0.

## Test plan

- One new loop in `tests/unit/auto-update-test.sh` (Step 1). It fails when the
  workflow compares the mode to any word the library cannot print.
- Pattern to follow: the surrounding `if [ -n "$github_dir" ]` block.

## Done criteria

- [ ] The direct unit test command ends with `all assertions passed`
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-auto-update'` exits 0
- [ ] `rg -n "'heavy'" .github/workflows/auto-update.yml` returns no matches
- [ ] `git diff --stat` shows only the two in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Line 105 or 110 of the workflow does not contain `AU_BUMP_MODE == 'heavy'`.
- `au_bump_mode` prints anything other than `full` or `light`.
- The Step 1 test passes before you apply Step 2. Then the bug is already fixed.

## Maintenance notes

- If someone renames the modes in `au_bump_mode`, the new test fails until the
  workflow literals follow. Update both, plus the `case` list in the test.
- Deferred: the `.bak` cleanup step runs before `assert-clean`, so the guard's
  `.bak` check can never fire in CI. Removing the cleanup step would fix that.
- Deferred: the PR body lists six vendored packages by hand and omits ten.
