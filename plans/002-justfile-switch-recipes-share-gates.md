# Plan 002: Every `just` recipe that switches the system runs the same preflight gates

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat e0b6770..HEAD -- justfile tests/unit/justfile-test.sh`
> If either file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `e0b6770`, 2026-11-10
- **Issue**: https://github.com/fpcMotif/nix-darwin/issues/423

## Why this matters

The `justfile` has three recipes that activate the system: `switch`,
`update-and-switch`, and `bump-and-switch`. Only `switch` runs the two
preflight gates:

- `_no-conflicts` refuses to build while merge conflict markers sit in a
  `.nix` file or `flake.lock`. Without it, the rebuild dies with an opaque Nix
  syntax error.
- `_unlanded` warns when the switch puts commits live that are not on `main`.
  A nightly job replaces those commits with `origin/main` at 04:30.

The other two recipes skip both gates, so the same mistakes pass silently
there. After this plan all three recipes run both gates, and a test keeps it so.

## Current state

Files:

- `justfile` — developer recipes at the repo root.
- `tests/unit/justfile-test.sh` — a shell test that greps the justfile text.
  It is wired as the Nix check `unit-justfile` in `tests/default.nix:69-73`.
  Do not edit `tests/default.nix`.

`justfile:111-116` today:

```just
build: _no-sudo _daemon _no-conflicts
    @darwin-rebuild build --flake . || { just _drift-hint; exit 1; }

# Activate the working-tree configuration (system + home-manager).
switch: _no-sudo _daemon _no-conflicts _unlanded
    @sudo darwin-rebuild switch --flake . || { just _drift-hint; exit 1; }
```

`justfile:136-147` today:

```just
update-and-switch: _no-sudo _daemon
    nix flake update
    sudo darwin-rebuild switch --flake .

# Run every scripts/update-*.sh updater, then activate. This is what the
# nightly auto-update GitHub workflow does, but on-demand. Forces the full
# bump: an explicit human invocation wants fresh nixpkgs too (issue #336).
# The variable sits on the runner's line: just runs each recipe line in its
# own shell, so a separate `export` line would never reach the updaters.
bump-and-switch: _no-sudo _daemon
    AU_FORCE_FULL_BUMP=1 bash scripts/lib/auto-update.sh run-updaters
    sudo darwin-rebuild switch --flake .
```

The last block of `tests/unit/justfile-test.sh` today (the end of the file):

```bash
# These recipes run nix, which fails while the daemon or activate-system is down.
for recipe in build switch update-and-switch bump-and-switch; do
  grep -qE "^${recipe}:.*\b_daemon\b" "$justfile" || {
    echo "justfile: recipe '${recipe}' must depend on _daemon" >&2
    exit 1
  }
done
```

Conventions that apply:

- Gates are `just` dependencies on the recipe header line. They run before
  the recipe body, in the order listed.
- `_unlanded` only prints a warning. It never fails the recipe.
- This repo blocks new code comments outside docs work (a `doc-lock` hook).
  Do not add or change any comment in either file.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Unit test | `bash tests/unit/justfile-test.sh justfile` | exit 0, no output |
| Recipe parse | `just --list` | exit 0, lists `update-and-switch` and `bump-and-switch` |
| Nix gate (macOS) | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-justfile'` | exit 0 |
| Nix gate (Linux) | `nix build --no-link --print-build-logs '.#checks.x86_64-linux.unit-justfile'` | exit 0 |

Never run `just switch`, `just update-and-switch`, `just bump-and-switch`, or
any `darwin-rebuild` command. They change the live system.

## Scope

**In scope** (the only files you may modify):

- `justfile` (two header lines only)
- `tests/unit/justfile-test.sh` (append one block)

**Out of scope** (do NOT touch):

- The recipe bodies. Do not add the `|| { just _drift-hint; exit 1; }`
  suffix to the two recipes. That is a separate choice for the maintainer.
- `tests/default.nix`. The check is already wired, and that file has
  uncommitted local changes.
- Every comment in the justfile.
- The hardcoded `aarch64-darwin` and `darwinConfigurations.f` names in other
  recipes.

## Git workflow

- Branch: `advisor/002-justfile-switch-recipes-share-gates`.
- One commit. Message style follows the repo, for example
  `fix(just): Name the nightly 04:30 auto-switch in the unlanded warning`. Use:
  `fix(just): Run the conflict and unlanded gates before every switch recipe`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Add the failing test

Append this block to the end of `tests/unit/justfile-test.sh`:

```bash

for recipe in build switch update-and-switch bump-and-switch; do
  grep -qE "^${recipe}:.*\b_no-conflicts\b" "$justfile" || {
    echo "justfile: recipe '${recipe}' must depend on _no-conflicts" >&2
    exit 1
  }
done
for recipe in switch update-and-switch bump-and-switch; do
  grep -qE "^${recipe}:.*\b_unlanded\b" "$justfile" || {
    echo "justfile: recipe '${recipe}' must depend on _unlanded" >&2
    exit 1
  }
done
```

**Verify**: `bash tests/unit/justfile-test.sh justfile` → exit 1 with exactly
this line on stderr:

```
justfile: recipe 'update-and-switch' must depend on _no-conflicts
```

### Step 2: Add the gates to the two recipe headers

In `justfile`, change the header line

```just
update-and-switch: _no-sudo _daemon
```

to

```just
update-and-switch: _no-sudo _daemon _no-conflicts _unlanded
```

and change the header line

```just
bump-and-switch: _no-sudo _daemon
```

to

```just
bump-and-switch: _no-sudo _daemon _no-conflicts _unlanded
```

Change nothing else.

**Verify**: `bash tests/unit/justfile-test.sh justfile` → exit 0, no output.
**Verify**: `just --list` → exit 0.
**Verify**: `git diff --stat -- justfile` → `1 file changed, 2 insertions(+), 2 deletions(-)`.

### Step 3: Run the Nix gate

Build the `unit-justfile` check for your platform (see "Commands you will need").

**Verify**: the `nix build` command exits 0.

## Test plan

- The appended block in `tests/unit/justfile-test.sh` asserts both gates on
  every switching recipe. Step 1 proves it fails on the old justfile.
- Structural pattern: the `_daemon` loop directly above the new block.
- Verification: `bash tests/unit/justfile-test.sh justfile` → exit 0.

## Done criteria

ALL must hold:

- [ ] `bash tests/unit/justfile-test.sh justfile` exits 0
- [ ] `grep -cE '^(switch|update-and-switch|bump-and-switch):.*_no-conflicts _unlanded' justfile` returns `3`
- [ ] `just --list` exits 0
- [ ] The Nix check `unit-justfile` builds for the current platform
- [ ] `git status --short` lists only `justfile` and `tests/unit/justfile-test.sh`
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Either recipe header does not match the "Current state" excerpt.
- Step 1 passes (exit 0) or fails with a different message. The test would
  then not be checking what this plan fixes.
- `just --list` fails after step 2.
- A hook blocks an edit and names a comment change.

## Maintenance notes

- A new recipe that runs `darwin-rebuild switch` must add its name to both
  loops in `tests/unit/justfile-test.sh`.
- `_no-conflicts` runs before `nix flake update` in `update-and-switch`. It
  checks the tree as it is before the update, which is the intended behavior.
- Deferred: the two recipes still lack the `_drift-hint` failure message that
  `switch` prints. Left out to keep this change to two lines.
