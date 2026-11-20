# Plan 007: Each flake input is bumped by exactly one updater

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- scripts/update-crush.sh scripts/update-claude-code.sh scripts/update-flake-inputs.sh scripts/lib/auto-update.sh tests/unit/auto-update-test.sh`
> Plans 004 and 005 edit the test file, and that is expected. If any other
> file changed, compare the "Current state" excerpts against the live code.
> On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/005-nightly-pr-title-names-the-real-bump-mode.md (same test file, land in order)
- **Category**: bug
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

Three updater scripts bump flake inputs, and two of them repeat work the third
does. `update-crush.sh` build-checks its bump, but `update-flake-inputs.sh`
runs later and bumps the same input again with no build. This plan makes the
general updater skip inputs that have a dedicated updater, and deletes the
dedicated updater that adds nothing. The cadence policy for nixpkgs is unchanged.

## Why this matters

The runner executes `scripts/update-*.sh` in name order and restores `pkgs/`
and `flake.lock` when one fails. Suppose a new `charm-nur` revision breaks the
crush build. `update-crush.sh` fails and is rolled back. A few scripts later
`update-flake-inputs.sh` bumps every top-level input, `charm-nur` included,
and nothing builds crush. The broken revision lands in the nightly PR anyway.

## Current state

Files:

- `scripts/update-crush.sh` — bumps input `charm-nur`, then builds `.#crush`. Keep.
- `scripts/update-claude-code.sh` — bumps input `claude-code` with no build. Redundant.
- `scripts/update-flake-inputs.sh` — bumps every top-level input, minus the
  heavy ones off the cadence day.
- `scripts/lib/auto-update.sh` — shared library. Holds the heavy-input policy.
- `tests/unit/auto-update-test.sh` — shell test, Nix check `unit-auto-update`.
  Argument 4 is the `scripts` directory, stored in `scripts_dir`. It may be empty.

`scripts/update-crush.sh:9-11` today:

```bash
before=$(crush_version)
nix flake update charm-nur 2>&1 | tail -10
au_build .#crush
```

`scripts/update-claude-code.sh:9-11` today:

```bash
before=$(locked_rev)
nix flake update claude-code 2>&1 | tail -50
after=$(locked_rev)
```

`scripts/update-flake-inputs.sh:5-11` today:

```bash
weekday=$(au_today_weekday)
# A hand-maintained input list would rot the first time an input is added.
mapfile -t all_inputs < <(nix flake metadata --json | jq -r '.locks.nodes.root.inputs | keys[]')
[ "${#all_inputs[@]}" -gt 0 ] || { echo "flake-inputs: no top-level inputs found" >&2; exit 1; }

mapfile -t inputs_to_bump < <(au_inputs_to_bump "$weekday" "${all_inputs[@]}")
[ "${#inputs_to_bump[@]}" -gt 0 ] || { echo "flake-inputs: nothing to bump today" >&2; exit 0; }
```

`scripts/lib/auto-update.sh:22-38` today:

```bash
# A nixpkgs bump re-derives stdenv and rehashes the Darwin closure, so heavy
# inputs move only on the cadence day (issue #336).
AU_HEAVY_INPUTS="nixpkgs"

AU_CADENCE_DAY=1

au_today_weekday() {
  printf '%s\n' "${AU_WEEKDAY_OVERRIDE:-$(date -u +%u)}"
}

au_is_heavy_input() {
  local input=$1 heavy
  for heavy in $AU_HEAVY_INPUTS; do
    [ "$input" = "$heavy" ] && return 0
  done
  return 1
}
```

The runner, `scripts/lib/auto-update.sh:461-464`, globs the scripts:

```bash
  if [ ${#scripts[@]} -eq 0 ]; then
    scripts=(scripts/update-*.sh)
    [ -e "${scripts[0]}" ] || scripts=()
  fi
```

So deleting a script removes it from the nightly run with no other edit.

References to the two scripts, checked on 2026-11-17 with
`rg -n 'update-claude-code|update-crush'` outside `plans/` and `references/`:
no file names either script. The workflow's PR body mentions the inputs
`claude-code` and `charm-nur/crush` only as examples of flake inputs.

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work. Add
  no comments. A comment may be deleted together with the code it describes.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Unit test, direct | `bash tests/unit/auto-update-test.sh scripts/lib/auto-update.sh modules/darwin/auto-switch.nix pkgs scripts .github` | last line `auto-update-test: all assertions passed` |
| Nix gate | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update'` | exit 0 |
| Syntax | `bash -n scripts/update-flake-inputs.sh && bash -n scripts/lib/auto-update.sh` | exit 0 |

Do not run `bash scripts/update-flake-inputs.sh` or `just bump-and-switch`.
They rewrite `flake.lock`.

## Scope

**In scope** (the only files you may modify):

- `scripts/lib/auto-update.sh` (add one variable and one function)
- `scripts/update-flake-inputs.sh` (one line)
- `scripts/update-claude-code.sh` (delete)
- `tests/unit/auto-update-test.sh` (insert one block)

**Out of scope** (do NOT touch):

- `scripts/update-crush.sh`. It is the build-checked owner of `charm-nur`.
- `au_inputs_to_bump` and `au_bump_mode`. Their behaviour is tested and correct.
- `flake.nix` and `flake.lock`.
- `.github/workflows/auto-update.yml`.

## Git workflow

- Branch: `advisor/007-one-updater-owns-each-flake-input`.
- One commit: `fix(auto-update): let update-crush own charm-nur and drop the claude-code duplicate`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Add the failing test

In `tests/unit/auto-update-test.sh`, insert this block directly above the line
`grep -qF 'archive --format=tar' "$auto_switch"`:

```bash
got=$(printf '%s\n' charm-nur darwin nixpkgs | au_without_dedicated_inputs | tr '\n' ' ')
[ "$got" = "darwin nixpkgs " ] || fail "au_without_dedicated_inputs kept a dedicated input: $got"

if [ -n "$scripts_dir" ]; then
  for input in $AU_DEDICATED_INPUTS; do
    owners=$(grep -lE "nix flake update ${input}( |\$)" "$scripts_dir"/update-*.sh || true)
    [ "$(printf '%s\n' "$owners" | grep -c .)" -eq 1 ] \
      || fail "dedicated input '$input' needs exactly one updater that runs 'nix flake update $input', found: $owners"
  done
  grep -qF 'au_without_dedicated_inputs' "$scripts_dir/update-flake-inputs.sh" \
    || fail "update-flake-inputs.sh does not skip dedicated inputs"
fi
```

**Verify**: run the direct unit test command. It must FAIL with
`au_without_dedicated_inputs: command not found`.

### Step 2: Add the policy to the library

In `scripts/lib/auto-update.sh`, directly after the closing `}` of
`au_is_heavy_input` (line 38) and its following blank line, add:

```bash
AU_DEDICATED_INPUTS="charm-nur"

au_without_dedicated_inputs() {
  local input dedicated skip
  while IFS= read -r input; do
    skip=0
    for dedicated in $AU_DEDICATED_INPUTS; do
      [ "$input" = "$dedicated" ] && skip=1
    done
    [ "$skip" -eq 1 ] || printf '%s\n' "$input"
  done
}

```

**Verify**: `bash -n scripts/lib/auto-update.sh` exits 0.

### Step 3: Skip dedicated inputs in the general updater

In `scripts/update-flake-inputs.sh`, change line 7 from:

```bash
mapfile -t all_inputs < <(nix flake metadata --json | jq -r '.locks.nodes.root.inputs | keys[]')
```

to:

```bash
mapfile -t all_inputs < <(nix flake metadata --json | jq -r '.locks.nodes.root.inputs | keys[]' | au_without_dedicated_inputs)
```

**Verify**: `bash -n scripts/update-flake-inputs.sh` exits 0.

### Step 4: Delete the redundant updater

Delete `scripts/update-claude-code.sh`. The input `claude-code` is not in
`AU_DEDICATED_INPUTS`, so `update-flake-inputs.sh` keeps bumping it.

**Verify**: `rg -n 'update-claude-code' --glob '!plans/**' --glob '!references/**' .` prints nothing.

### Step 5: Run the tests

**Verify**: the direct unit test command ends with `all assertions passed`.
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update'` exits 0.

## Test plan

- New assertions in `tests/unit/auto-update-test.sh` (Step 1):
  - the filter drops `charm-nur` and keeps the rest;
  - every dedicated input has exactly one script that bumps it by name;
  - the general updater calls the filter.
- Pattern to follow: the `au_inputs_to_bump` assertions around line 118.

## Done criteria

- [ ] The direct unit test command ends with `all assertions passed`
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-auto-update'` exits 0
- [ ] `test ! -e scripts/update-claude-code.sh`
- [ ] `rg -c 'au_without_dedicated_inputs' scripts/update-flake-inputs.sh` prints `1`
- [ ] `git status --short` lists only the in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Any file outside `plans/` and `references/` names `update-claude-code.sh`.
- `scripts/update-crush.sh` no longer contains `nix flake update charm-nur`.
- The Step 1 loop reports zero or two owners for `charm-nur` after Step 4.

## Maintenance notes

- To give another flake input a build-checked updater, add its name to
  `AU_DEDICATED_INPUTS` and write `scripts/update-<name>.sh` with
  `nix flake update <name>` followed by `au_build`. The test enforces the pairing.
- `update-crush.sh` bumps `charm-nur` every night, on every weekday. That
  matches the old behaviour, because `charm-nur` was never a heavy input.
- A reviewer should check that the nightly run log still shows a
  `=== scripts/update-crush.sh ===` group and no claude-code group.
