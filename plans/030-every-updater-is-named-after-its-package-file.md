# Plan 030: Every updater script is named after its package file, and a test keeps it so

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- scripts pkgs/default.nix modules/darwin/rime.nix tests/default.nix tests/unit/auto-update-test.sh tests/README.md`
> The nightly updater changes `pkgs/*.nix` pins daily. That is expected. If a
> script under `scripts/` was added, removed, or renamed, compare the list
> under "Current state" with `ls scripts`. On a mismatch, treat it as a STOP
> condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/019-pin-data-pilot-on-hk-bin.md (soft: see "Maintenance notes")
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

Five updater scripts are named differently from the package file they
rewrite, and one package is built by path from a module instead of being
registered in the overlay. So nothing can check mechanically that an updater
has a package or where a package is registered. This plan renames the five
scripts, registers the one package, and adds a test for the naming rule. No
package's build changes.

## Why this matters

`scripts/update-hk.sh` rewrites `pkgs/hk-bin.nix`. A reader has to open the
script to learn that. Issue #430 asks which pinned packages have no updater,
and today that question needs a hand-built table. With one naming rule,
`scripts/update-<name>.sh` pairs with `pkgs/<name>.nix`, and a shell test
answers it.

## Current state

### The updater scripts and the files they rewrite

`ls scripts` on 2026-11-27 listed 18 `update-*.sh` scripts. Thirteen already
match a package file or are flake-input updaters:

| Script | Rewrites | Match |
|---|---|---|
| `update-codex.sh` | `pkgs/codex.nix` | yes |
| `update-droid.sh` | `pkgs/droid.nix` | yes |
| `update-fff-mcp.sh` | `pkgs/fff-mcp.nix` | yes |
| `update-hammerspoon.sh` | `pkgs/hammerspoon.nix` | yes |
| `update-mole.sh` | `pkgs/mole.nix` | yes |
| `update-nub.sh` | `pkgs/nub.nix` | yes |
| `update-oh-my-pi.sh` | `pkgs/oh-my-pi.nix` | yes |
| `update-pi-coding-agent.sh` | `pkgs/pi-coding-agent.nix` | yes |
| `update-sf-mono.sh` | `pkgs/sf-mono.nix` | yes |
| `update-sourcegraph-amp.sh` | `pkgs/sourcegraph-amp.nix` | yes |
| `update-squirrel.sh` | `pkgs/squirrel.nix` | yes |
| `update-crush.sh` | the `charm-nur` flake input | flake input |
| `update-flake-inputs.sh` | `flake.lock` | flake input |

Five do not match:

| Script today | Rewrites | Name after this plan |
|---|---|---|
| `update-hk.sh` | `pkgs/hk-bin.nix` | `update-hk-bin.sh` |
| `update-uv.sh` | `pkgs/uv-bin.nix` | `update-uv-bin.sh` |
| `update-hunk.sh` | `pkgs/hunk-bin.nix` | `update-hunk-bin.sh` |
| `update-bun-canary.sh` | `pkgs/bun-canary-bin.nix` | `update-bun-canary-bin.sh` |
| `update-zed-nightly.sh` | `pkgs/zed-nightly-bin.nix` | `update-zed-nightly-bin.sh` |

### How updaters are found and named elsewhere

`scripts/lib/auto-update.sh:471-476` finds them by glob, so a rename needs no
list edit:

```bash
au_run_updaters() {
  local scripts=("$@") snap s failed=0
  if [ ${#scripts[@]} -eq 0 ]; then
    scripts=(scripts/update-*.sh)
    [ -e "${scripts[0]}" ] || scripts=()
  fi
```

Each script passes its own display name, for example
`scripts/update-droid.sh:15`: `au_bump_release --name droid --file pkgs/droid.nix ...`.
The display name is not derived from the file name.

References to the five old names, measured on 2026-11-27 with
`rg -n 'update-(hk|uv|hunk|bun-canary|zed-nightly)\b' --glob '!plans/**' --glob '!references/**' .`:

- `modules/home/zed.nix:271`, inside a comment: `# with scripts/update-zed-nightly.sh.`
- `tests/unit/auto-update-test.sh:334`: `cp "$scripts_dir/update-bun-canary.sh" "$canary_dir/scripts/"`
- `tests/unit/auto-update-test.sh:343`: `bash "$canary_dir/scripts/update-bun-canary.sh" 2>&1`

### The package registered outside the overlay

`modules/darwin/rime.nix:20-25`:

```nix
    schemaSource = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../pkgs/rime-frost.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../../pkgs/rime-frost.nix { }";
      description = "Schema tree mirrored into ~/Library/Rime on every switch.";
    };
```

Every other file in `pkgs/` is registered in `pkgs/default.nix` inside the
`martin = { ... }` set, one line each. Exemplar, `pkgs/default.nix:47`:

```nix
    mole = final.callPackage ./mole.nix { };
```

### How a shell test is registered

`tests/default.nix`, the exemplar entry:

```nix
  unit-rolling-pins = shellTest "unit-rolling-pins" {
    script = ./unit/rolling-pins-test.sh;
    inputs = [ pkgs.gnugrep ];
    args = [ ../pkgs ../scripts ];
  };
```

Every registered check needs a row in the table in `tests/README.md`, or the
`unit-tests-readme` check fails. A row looks like:

```markdown
| `unit-rolling-pins`                 | Every pin at a URL without a version has a hash-driven updater, and no `rolling_pins` entry is left for a package that moved to a versioned URL. |
```

### What this plan does not rename, and why

- The `-bin` suffix on package files. Nine prebuilt packages carry it and
  about ten do not. Renaming package files changes overlay attribute names,
  store paths, and the files the `pkgnix` merge driver matches. The cost is
  larger than the gain. The rule this plan adopts is narrower: an updater is
  named after the package file, whatever that file is called.
- `pkgs/tsrs-bin.nix` and `pkgs/zig-dev-bin.nix`, which register as the
  top-level `pkgs.tsrs` and `pkgs.zig`. They replace nixpkgs packages of
  those names on purpose. An earlier audit recorded that as accepted.

Repo rules that apply:

- A `doc-lock` hook blocks Markdown and comment changes outside docs work.
  This plan edits one comment (`modules/home/zed.nix:271`) and one Markdown
  table. If the hook blocks an edit, stop and report. The operator then opens
  docs work.
- New code carries no comments. The new test script below has none.
- Nix sees only files Git tracks. `git mv` stages its result. After creating
  a file, run `git add -N <path>`.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| New test, direct | `bash tests/unit/updater-names-test.sh scripts pkgs` | see steps |
| New check | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-updater-names'` | exit 0 |
| Updater checks | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update' '.#checks.aarch64-darwin.unit-rolling-pins'` | exit 0 |
| README guard | `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` | exit 0 |
| Rime invariance | `nix eval --raw '.#darwinConfigurations.f.config.martin.rime.schemaSource.drvPath'` | prints one `.drv` path |
| Format | `nix fmt -- --check pkgs/default.nix modules/darwin/rime.nix tests/default.nix` | exit 0 |
| Shell lint | `nix develop --command shellcheck tests/unit/updater-names-test.sh` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `scripts/update-hk.sh`, `update-uv.sh`, `update-hunk.sh`, `update-bun-canary.sh`, `update-zed-nightly.sh` (rename only)
- `tests/unit/auto-update-test.sh` (lines 334 and 343)
- `modules/home/zed.nix` (the path in the comment on line 271)
- `tests/unit/updater-names-test.sh` (create)
- `tests/default.nix` (one new entry)
- `tests/README.md` (one new table row)
- `pkgs/default.nix` (one new line)
- `modules/darwin/rime.nix` (lines 22-23)

**Out of scope** (do NOT touch):

- The contents of any updater script.
- Any file name under `pkgs/`.
- `scripts/lib/auto-update.sh`.
- `.gitattributes` and `scripts/git-merge-pkgnix.sh`.
- `AGENTS.md` and `ARCHITECTURE.md`. Plan 031 writes the naming rule into
  `AGENTS.md`.

## Git workflow

- Branch: `advisor/030-every-updater-is-named-after-its-package-file`.
- Three commits:
  1. `test: add unit-updater-names for the updater naming rule`
  2. `refactor(scripts): name five updaters after their package files`
  3. `refactor(rime): register rime-frost in the overlay`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Write the test and watch it fail

Create `tests/unit/updater-names-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

scripts_dir=$1
pkgs_dir=$2
flake_input_updaters=" crush flake-inputs "

fail=0
count=0
for script in "$scripts_dir"/update-*.sh; do
  [ -e "$script" ] || continue
  name=$(basename "$script" .sh)
  name=${name#update-}
  count=$((count + 1))
  case $flake_input_updaters in
    *" $name "*) continue ;;
  esac
  if [ ! -f "$pkgs_dir/$name.nix" ]; then
    echo "scripts/update-$name.sh: no pkgs/$name.nix. Name the updater after the package file it rewrites." >&2
    fail=1
  fi
done

if [ "$count" -eq 0 ]; then
  echo "no update-*.sh script found in $scripts_dir" >&2
  exit 1
fi
[ "$fail" -eq 0 ] || exit 1
echo "PASS $count updaters are named after a package file"
```

Run `git add -N tests/unit/updater-names-test.sh`.

**Verify**: the "New test, direct" command exits 1 and prints exactly five
lines, one each for `update-hk.sh`, `update-uv.sh`, `update-hunk.sh`,
`update-bun-canary.sh`, and `update-zed-nightly.sh`. If it prints a different
set, that is a STOP condition. The Shell lint command exits 0.

### Step 2: Rename the five scripts

1. Run the five moves:
   - `git mv scripts/update-hk.sh scripts/update-hk-bin.sh`
   - `git mv scripts/update-uv.sh scripts/update-uv-bin.sh`
   - `git mv scripts/update-hunk.sh scripts/update-hunk-bin.sh`
   - `git mv scripts/update-bun-canary.sh scripts/update-bun-canary-bin.sh`
   - `git mv scripts/update-zed-nightly.sh scripts/update-zed-nightly-bin.sh`
2. In `tests/unit/auto-update-test.sh`, change `update-bun-canary.sh` to
   `update-bun-canary-bin.sh` on lines 334 and 343.
3. In `modules/home/zed.nix` line 271, change the path in the comment to
   `scripts/update-zed-nightly-bin.sh`. Change nothing else on the line.

**Verify**: the "New test, direct" command exits 0 and prints
`PASS 18 updaters are named after a package file`.
`rg -n 'update-(hk|uv|hunk|bun-canary|zed-nightly)\.sh' --glob '!plans/**' --glob '!references/**' .`
prints nothing. The Updater checks command exits 0.

### Step 3: Register the check

1. In `tests/default.nix`, add after the `unit-rolling-pins` entry:

   ```nix
     unit-updater-names = shellTest "unit-updater-names" {
       script = ./unit/updater-names-test.sh;
       inputs = [ pkgs.coreutils ];
       args = [ ../scripts ../pkgs ];
     };
   ```

2. In `tests/README.md`, add a row to the checks table after the
   `unit-rolling-pins` row:

   ```markdown
   | `unit-updater-names`                | Every `scripts/update-<name>.sh` has a `pkgs/<name>.nix`, except the two flake-input updaters. |
   ```

**Verify**: the New check and README guard commands exit 0. Commit the test,
its registration, and the README row as commit 1. Commit the five renames and
their two reference edits as commit 2.

### Step 4: Register `rime-frost` in the overlay

1. Run the Rime invariance command and save its output as `RIME_BEFORE`.
2. In `pkgs/default.nix`, inside `martin = { ... }`, add after the `recall` line:

   ```nix
       rime-frost = final.callPackage ./rime-frost.nix { };
   ```

3. In `modules/darwin/rime.nix`, change lines 22-23 to:

   ```nix
         default = pkgs.martin.rime-frost;
         defaultText = lib.literalExpression "pkgs.martin.rime-frost";
   ```

**Verify**: the Rime invariance command prints `RIME_BEFORE` exactly.
`rg -n '\.\./\.\./pkgs' modules` prints nothing. The Format command exits 0.
`nix build --no-link '.#checks.aarch64-darwin.unit-overlay'` exits 0.
Commit (commit 3).

## Test plan

- New test: `tests/unit/updater-names-test.sh`, registered as
  `unit-updater-names`. It covers one rule: every updater script has a
  package file of the same name, with two named exceptions.
- Step 1 watches the test fail on the five mismatched names before any
  rename. Step 2 watches it pass.
- Pattern followed: `tests/unit/rolling-pins-test.sh` and its registry entry.
- `unit-auto-update` runs the renamed `update-bun-canary-bin.sh` against a
  fixture, which proves the rename broke nothing in the shared library.

## Done criteria

- [ ] `bash tests/unit/updater-names-test.sh scripts pkgs` exits 0
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-updater-names' '.#checks.aarch64-darwin.unit-auto-update' '.#checks.aarch64-darwin.unit-rolling-pins' '.#checks.aarch64-darwin.unit-tests-readme'` exits 0
- [ ] `rg -n 'update-(hk|uv|hunk|bun-canary|zed-nightly)\.sh' --glob '!plans/**' --glob '!references/**' .` returns no matches
- [ ] `rg -n '\.\./\.\./pkgs' modules` returns no matches
- [ ] The Step 4 invariance check passed
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Step 1's failure list is not exactly the five scripts named in this plan.
  A new updater may have been added since.
- A workflow file names an updater script by hand. Check with
  `rg -n 'update-[a-z-]+\.sh' .github`. Expect no hit that names one of the
  five scripts.
- `unit-rolling-pins` or `unit-auto-update` fails after the renames for a
  reason other than the two lines this plan edits. Something may derive a
  package name from the script file name.
- `RIME_BEFORE` differs after Step 4.
- `plans/019-pin-data-pilot-on-hk-bin.md` is IN PROGRESS in
  `plans/README.md`. It edits `scripts/update-hk.sh`. Wait for it.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- Plan 019 edits `scripts/update-hk.sh` and adds assertions that name it. If
  plan 019 lands after this plan, its executor must use
  `scripts/update-hk-bin.sh`. If it lands first, this plan's Step 2 search
  will find its new references. Update each one.
- Local habit: anyone who runs `bash scripts/update-hk.sh` by hand must use
  the new name. `just bump-and-switch` and the nightly workflow use the glob
  and need no change.
- Issue #430 (seven pinned packages have no updater) can now be answered by
  listing `pkgs/*.nix` files that have no `scripts/update-<name>.sh`. A
  second test for that direction needs an allowlist of deliberately held
  pins, which is the maintainer's decision.
