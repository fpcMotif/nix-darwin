# Plan 006: The `pkgnix` merge driver picks the newer version by semver, and has a test

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- scripts/git-merge-pkgnix.sh scripts/lib/auto-update.sh tests/default.nix tests/README.md`
> If `scripts/git-merge-pkgnix.sh` changed, compare the "Current state"
> excerpts against the live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

When two pin bumps collide in `pkgs/*.nix`, a git merge driver keeps the side
with the newer version. It ranks versions with `sort -V`, which puts
`1.2.3-alpha.1` above `1.2.3`. This plan switches it to the repo's own semver
helper and adds the driver's first test. The driver's other rules stay as they are.

## Why this matters

`pkgs/codex.nix` tracks a prerelease channel. When a local bump to a stable
release meets a nightly bump to an alpha of the same version, the driver
silently keeps the alpha. That is a downgrade with no conflict marker. The
library already documents this exact `sort -V` trap and ships a fix for it.

## Current state

Files:

- `scripts/git-merge-pkgnix.sh` — the merge driver. Git calls it as
  `git-merge-pkgnix.sh %O %A %B %L %P` (base, ours, theirs, marker size, path).
  It must leave the result in the "ours" file. Exit 0 means resolved.
- `scripts/lib/auto-update.sh` — defines `au_latest_semver`. Sourcing it has no
  side effects: its command dispatcher runs only when the file is executed directly.
- `.gitattributes` — `pkgs/*.nix merge=pkgnix`.
- `tests/default.nix` — the check registry.
- `tests/README.md` — has a table with one row per check. The check
  `unit-tests-readme` fails when the table and the registry disagree.

`scripts/git-merge-pkgnix.sh:60-71` today:

```bash
# Zed nightly builds share one semver, so build metadata after `+` is ignored.
# A tie keeps "ours", which during rebase or stash apply is the CI-verified upstream.
# A side that is itself mispaired is trusted. The updater scripts re-prefetch its hash.
ours_semver=${ours_version%%+*} theirs_semver=${theirs_version%%+*}
newer_semver=$(printf '%s\n%s\n' "$ours_semver" "$theirs_semver" | sort -V | tail -n1)
if [ "$ours_semver" != "$theirs_semver" ] && [ "$newer_semver" = "$theirs_semver" ]; then
  cat "$theirs" >"$ours"
  note "$path auto-resolved to version $theirs_version (dropped $ours_version)"
else
  note "$path auto-resolved to version $ours_version (dropped $theirs_version)"
fi
exit 0
```

The script already defines this helper at lines 21-25. Reuse it:

```bash
exit_with_conflict_markers() {
  git merge-file --marker-size="$marker" "$ours" "$base" "$theirs" || true
  note "$path $1; left markers for manual resolution"
  exit 1
}
```

`scripts/lib/auto-update.sh:234-248` today:

```bash
# `sort -V` ranks 1.2.3-alpha.1 above 1.2.3. jq orders numbers before strings
# and a shorter array before its extensions, which matches semver precedence.
au_latest_semver() {
  jq -Rrs '
    split("\n") | map(select(length > 0))
    | max_by(
        ...
      ) // empty'
}
```

It reads versions on stdin, one per line, and prints the highest. It needs `jq`.
It errors on a version whose core is not numeric, such as `canary`.

The test helper in `tests/default.nix:13-17`:

```nix
  shellTest = name: { script, inputs, args ? [ ] }:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.bash ] ++ inputs; } ''
      bash ${script} ${lib.concatMapStringsSep " " (arg: "${arg}") args}
      touch $out
    '';
```

An existing registration to copy, `tests/default.nix:79-82` region:

```nix
  unit-rolling-pins = shellTest "unit-rolling-pins" {
    script = ./unit/rolling-pins-test.sh;
```

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments outside docs work. Add
  no comments to code. The `tests/README.md` row in Step 4 is Markdown. If the
  hook blocks it, stop and report the exact row text.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Driver test, direct | `bash tests/unit/git-merge-pkgnix-test.sh scripts` | last line `git-merge-pkgnix-test: all assertions passed` |
| Nix gate | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-git-merge-pkgnix'` | exit 0 |
| README guard | `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` | exit 0 |
| Format | `nix fmt -- --check tests/default.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `scripts/git-merge-pkgnix.sh`
- `tests/unit/git-merge-pkgnix-test.sh` (create)
- `tests/default.nix` (add one registration)
- `tests/README.md` (add one table row)

**Out of scope** (do NOT touch):

- `scripts/lib/auto-update.sh`.
- `.gitattributes`. Extending the driver to `pkgs/sourcegraph-amp/package*.json`
  is a separate decision.
- `modules/home/git.nix`, which registers the driver.
- The `side_pickable_line` regex and every other rule in the driver.

## Git workflow

- Branch: `advisor/006-pkgnix-merge-driver-orders-versions-by-semver`.
- One commit: `fix(pkgnix): rank colliding pin versions by semver, not sort -V`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Write the failing test

Create `tests/unit/git-merge-pkgnix-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

scripts_dir=$1
driver="$scripts_dir/git-merge-pkgnix.sh"

fail() { echo "git-merge-pkgnix-test: $*" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pin() {
  printf '{\n  version = "%s";\n  hash = "sha256-%s=";\n}\n' "$1" "$2"
}

merge() {
  pin "$1" BASE >"$work/base"
  pin "$2" OURS >"$work/ours"
  pin "$3" THEIRS >"$work/theirs"
  bash "$driver" "$work/base" "$work/ours" "$work/theirs" 7 pkgs/sample.nix 2>/dev/null
}

merge 0.47.0 0.48.0 0.48.0-alpha.3 || fail "driver left a conflict for stable-vs-alpha"
grep -qF 'version = "0.48.0";' "$work/ours" || fail "driver kept the alpha over its stable release"
grep -qF 'sha256-OURS=' "$work/ours" || fail "driver mispaired the stable version with the other side's hash"

merge 0.47.0 0.48.0 0.49.0 || fail "driver left a conflict for two stable versions"
grep -qF 'version = "0.49.0";' "$work/ours" || fail "driver dropped the newer stable version"
grep -qF 'sha256-THEIRS=' "$work/ours" || fail "driver mispaired the newer version with the older hash"

merge 0.47.0 0.9.0 0.10.0 || fail "driver left a conflict for 0.9.0 vs 0.10.0"
grep -qF 'version = "0.10.0";' "$work/ours" || fail "driver compared minor versions as text"

if merge 0.47.0 canary 0.48.0; then
  fail "driver resolved a version it cannot compare"
fi
grep -qF '<<<<<<<' "$work/ours" || fail "driver left no conflict markers for an incomparable version"

echo "git-merge-pkgnix-test: all assertions passed"
```

**Verify**: `bash tests/unit/git-merge-pkgnix-test.sh scripts` FAILS with
`driver kept the alpha over its stable release`.

### Step 2: Use the semver helper in the driver

In `scripts/git-merge-pkgnix.sh`:

1. Directly below the line `set -euo pipefail`, add a blank line and then:

   ```bash
   . "$(dirname "${BASH_SOURCE[0]}")/lib/auto-update.sh"
   ```

2. Replace the line

   ```bash
   newer_semver=$(printf '%s\n%s\n' "$ours_semver" "$theirs_semver" | sort -V | tail -n1)
   ```

   with:

   ```bash
   newer_semver=$(printf '%s\n%s\n' "$ours_semver" "$theirs_semver" | au_latest_semver 2>/dev/null) || newer_semver=""
   if [ -z "$newer_semver" ]; then
     exit_with_conflict_markers "has versions that could not be compared"
   fi
   ```

Leave every existing comment in the file exactly as written.

**Verify**: `bash -n scripts/git-merge-pkgnix.sh` exits 0.
`bash tests/unit/git-merge-pkgnix-test.sh scripts` ends with `all assertions passed`.

### Step 3: Register the check

In `tests/default.nix`, directly after the closing `};` of the
`unit-rolling-pins = shellTest "unit-rolling-pins" { ... };` entry, add:

```nix
  unit-git-merge-pkgnix = shellTest "unit-git-merge-pkgnix" {
    script = ./unit/git-merge-pkgnix-test.sh;
    inputs = [ pkgs.git pkgs.jq pkgs.gnugrep pkgs.gnused pkgs.diffutils pkgs.coreutils ];
    args = [ ../scripts ];
  };
```

Then run `git add -N tests/unit/git-merge-pkgnix-test.sh`.

**Verify**: `nix fmt -- --check tests/default.nix` exits 0.

### Step 4: Add the README row

In `tests/README.md`, in the table under "What each test does", add this row
next to the `unit-rolling-pins` row. If that row does not exist, add it after
the `unit-auto-update` row:

```markdown
| `unit-git-merge-pkgnix`             | Runs `scripts/git-merge-pkgnix.sh` on colliding pins: a stable release beats its own alpha, the newer version keeps its own hash, and an incomparable version leaves conflict markers. |
```

**Verify**: `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` exits 0.
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-git-merge-pkgnix'` exits 0.

## Test plan

- New file `tests/unit/git-merge-pkgnix-test.sh` with four cases: stable beats
  its alpha (the bug), newer stable wins with its own hash, `0.10.0` beats
  `0.9.0`, and an incomparable version leaves markers.
- Structural pattern: `tests/unit/auto-update-test.sh` for the `fail` helper.

## Done criteria

- [ ] `bash tests/unit/git-merge-pkgnix-test.sh scripts` ends with `all assertions passed`
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-git-merge-pkgnix'` exits 0
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` exits 0
- [ ] `rg -n 'sort -V' scripts/git-merge-pkgnix.sh` returns no matches
- [ ] `git status --short` lists only the four in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The excerpt of `scripts/git-merge-pkgnix.sh:60-71` does not match the live file.
- Sourcing `scripts/lib/auto-update.sh` prints output or changes the working directory.
- The fourth test case resolves cleanly. Then `au_latest_semver` accepts
  non-numeric versions, and the fallback needs a different trigger.
- The `doc-lock` hook blocks the `tests/README.md` edit.

## Maintenance notes

- The driver now needs `jq` on PATH. Home Manager installs it for this user.
  Without `jq`, the driver leaves conflict markers instead of guessing.
- Two nightly tags with the same semver core compare by their suffix text. That
  order is arbitrary, as it was before. The updaters re-prefetch the hash.
- Plan 019 extends this driver to JSON pin files. It builds on this test.
