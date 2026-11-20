# Plan 019: Pilot — `hk-bin` keeps its version and hashes in a data file the updater rewrites with `jq`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- pkgs/hk-bin.nix scripts/update-hk.sh scripts/lib/auto-update.sh scripts/git-merge-pkgnix.sh .gitattributes`
> `pkgs/hk-bin.nix` had an uncommitted version bump when this plan was
> written. The version and hashes will differ from the excerpt. That is fine.
> Plans 004, 006, and 007 change the library and the merge driver. Read the
> live files and adapt names. If `au_bump_release` or `side_pickable_line`
> no longer exists, stop and report.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: 004, 006, 007 (same updater library, merge driver, and test file)
- **Category**: tech-debt
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

Each prebuilt package states its release assets twice: once in `pkgs/<name>.nix`
and once in `scripts/update-<name>.sh`. The updater then edits Nix source with
`sed` and a `perl` regex anchored on asset names. This plan moves one package,
`hk-bin`, to a JSON pin file that Nix reads and the updater rewrites with `jq`.
It is a pilot. The other packages keep the current mechanism.

## Why this matters

About 25 updater scripts repeat asset lists that the package files already
hold. The regex rewrite fails silently when an anchor stops matching, which
is why `au_set_block_hash` carries a follow-up `grep` guard. Data in JSON is
written whole by `jq`, so a rewrite cannot half-match. A pilot on one package
shows whether the merge driver and the nightly job cope before any wider move.

## Current state

Files:

- `pkgs/hk-bin.nix` — the package.
- `scripts/update-hk.sh` — its updater.
- `scripts/lib/auto-update.sh` — shared updater functions.
- `scripts/git-merge-pkgnix.sh` and `.gitattributes` — the merge driver for pin conflicts.
- `tests/unit/auto-update-test.sh` — check `unit-auto-update`.

`pkgs/hk-bin.nix:6-27` at `534fc39`:

```nix
let
  version = "2.12.0";

  releaseBase = "https://github.com/jdx/hk/releases/download/v${version}";

  sources = {
    aarch64-darwin = {
      asset = "hk-aarch64-apple-darwin.tar.gz";
      hash = "sha256-...";
    };
    aarch64-linux = {
      asset = "hk-aarch64-unknown-linux-musl.tar.gz";
      hash = "sha256-...";
    };
    x86_64-linux = {
      asset = "hk-x86_64-unknown-linux-musl.tar.gz";
      hash = "sha256-...";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "hk-bin is not packaged for ${stdenvNoCC.hostPlatform.system}");
in
```

The rest of the file uses `version`, `releaseBase`, `source.asset`,
`source.hash`, and `builtins.attrNames sources`.

`scripts/update-hk.sh` today (whole file):

```bash
#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release jdx/hk)
base="https://github.com/jdx/hk/releases/download/v${latest}"

assets=()
for asset in \
  hk-aarch64-apple-darwin.tar.gz \
  hk-aarch64-unknown-linux-musl.tar.gz \
  hk-x86_64-unknown-linux-musl.tar.gz
do
  assets+=(--asset "${base}/${asset}" "asset = \"${asset}\";")
done

au_bump_release --name hk --file pkgs/hk-bin.nix --version "$latest" \
  --attr .#martin.hk-bin "${assets[@]}"
```

Library functions you will call, all in `scripts/lib/auto-update.sh`:

- `au_latest_github_release OWNER/REPO` prints the latest version without `v`.
- `au_prefetch_sri URL` prints an SRI hash for a file.
- `au_require_sri HASH CONTEXT` returns 1 when the hash is not SRI.
- `au_build ATTR` builds a flake attribute.
- `au_report_change NAME OLD NEW` prints the change line.
- `au_assert_clean` greps `pkgs/` for `sha256-AAAAAAAA` and for the pattern
  `(hash|sha256|sha512|npmDepsHash|vendorHash|cargoHash) = ""`.

Read `au_bump_release` (starts near line 346) before Step 3. Your new function
must follow its order: stop early when the version is unchanged, prefetch
every hash, check each with `au_require_sri`, write, build, report.

The merge driver, `scripts/git-merge-pkgnix.sh:40` and `:49-51`:

```bash
side_pickable_line='^([[:space:]]*(version|url|rev|tag|hash|sha256|[A-Za-z0-9_-]*Hash)[[:space:]]*=[[:space:]]*"[^"]*";?,?|[[:space:]]*"?[A-Za-z0-9_.-]+"?[[:space:]]*=[[:space:]]*"sha(256|512)-[^"]*";?,?)$'
```

```bash
first_version_literal() {
  sed -nE 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$1" | head -n1
}
```

Both match Nix syntax (`key = "value";`). Neither matches JSON (`"key": "value",`).

`.gitattributes:5`:

```text
pkgs/*.nix merge=pkgnix
```

Consumers of the package: `modules/home/hk.nix:4`, `modules/home/doc-lock/default.nix:6`,
and `pkgs/default.nix:67`. None changes.

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Add no comments. If the `.gitattributes` comment needs a change, stop and report.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Edit with
  your edit tool. `sed` inside the scripts is code.
- Do not run `scripts/update-hk.sh` against the network as a test. It would
  bump the pin. The unit test below uses fixtures.

## Commands you will need

Run from the repo root, on the macOS host.

| Purpose | Command | Expected on success |
|---|---|---|
| Package invariance | `nix eval --raw '.#legacyPackages.aarch64-darwin.martin.hk-bin.drvPath'` | one `/nix/store/...drv` path |
| Linux invariance | `nix eval --raw '.#legacyPackages.x86_64-linux.martin.hk-bin.drvPath'` | one `/nix/store/...drv` path |
| Updater tests | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update'` | exit 0 |
| Merge driver tests | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-git-merge-pkgnix'` | exit 0 (exists after plan 006) |
| Rolling pins | `nix build --no-link '.#checks.aarch64-darwin.unit-rolling-pins'` | exit 0 |
| Format | `nix fmt -- --check pkgs/hk-bin.nix` | exit 0 |
| Shell lint | `nix develop --command shellcheck scripts/update-hk.sh scripts/lib/auto-update.sh scripts/git-merge-pkgnix.sh` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `pkgs/hk-bin.nix`
- `pkgs/hk-bin.sources.json` (create)
- `scripts/update-hk.sh`
- `scripts/lib/auto-update.sh` (one new function, one extended pattern)
- `scripts/git-merge-pkgnix.sh`
- `.gitattributes` (one new line)
- `tests/unit/auto-update-test.sh`
- `tests/unit/git-merge-pkgnix-test.sh` (exists after plan 006)

**Out of scope** (do NOT touch):

- Every other `pkgs/*.nix` and `scripts/update-*.sh`. This is a pilot.
- `au_bump_release`, `au_set_version`, and `au_set_block_hash`. Other packages use them.
- `.github/workflows/auto-update.yml`.

## Git workflow

- Branch: `advisor/019-pin-data-pilot-on-hk-bin`.
- Three commits:
  1. `refactor(hk): read the version and asset hashes from hk-bin.sources.json`
  2. `feat(auto-update): bump JSON pin files with jq, starting with hk`
  3. `fix(merge): teach the pkgnix driver the JSON pin shape`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baselines

Run both invariance commands. Save the paths as `HK_DARWIN` and `HK_LINUX`.

### Step 2: Move the pin data to JSON

Create `pkgs/hk-bin.sources.json`. Copy the version, asset names, and hashes
from the live `pkgs/hk-bin.nix`, not from this plan:

```json
{
  "version": "<version from hk-bin.nix>",
  "assets": {
    "aarch64-darwin": {
      "asset": "hk-aarch64-apple-darwin.tar.gz",
      "hash": "<hash from hk-bin.nix>"
    },
    "aarch64-linux": {
      "asset": "hk-aarch64-unknown-linux-musl.tar.gz",
      "hash": "<hash from hk-bin.nix>"
    },
    "x86_64-linux": {
      "asset": "hk-x86_64-unknown-linux-musl.tar.gz",
      "hash": "<hash from hk-bin.nix>"
    }
  }
}
```

In `pkgs/hk-bin.nix`, replace the `version = "...";` line and the whole
`sources = { ... };` binding with:

```nix
  pin = lib.importJSON ./hk-bin.sources.json;
  inherit (pin) version;
  sources = pin.assets;
```

Keep `releaseBase`, `source`, and everything after `in` unchanged.

Run `git add -N pkgs/hk-bin.sources.json`.

**Verify**: both invariance commands print `HK_DARWIN` and `HK_LINUX`.
`nix fmt -- --check pkgs/hk-bin.nix` exits 0. Commit (commit 1).

### Step 3: Add the JSON bump function and its test

Write the test first. In `tests/unit/auto-update-test.sh`, follow the way the
file already tests `au_set_block_hash`: it sources the library, builds a
fixture in a temp directory, calls the function, and greps the result. Add a
block that:

1. Writes a fixture pin file with version `1.0.0` and two assets with dummy
   SRI hashes.
2. Defines stub functions `au_prefetch_sri` (prints a fixed new SRI hash per
   URL), `au_build`, and `au_report_change` (both do nothing).
3. Calls `au_bump_json_pin --name demo --file "$fixture" --version 1.1.0 --attr .#x --url-template 'https://example.invalid/v{version}/{asset}'`.
4. Asserts with `jq -e` that `.version == "1.1.0"`, that both hashes equal the
   stub's value, and that both `asset` names are unchanged.
5. Calls it again with version `1.1.0` and asserts the file is byte-identical
   (`cmp`).
6. Redefines the `au_prefetch_sri` stub to print an empty string, calls with
   version `1.2.0`, and asserts a non-zero return and an unchanged file.

**Verify**: the Updater tests build **fails** with `au_bump_json_pin: command not found`.

Then add `au_bump_json_pin` to `scripts/lib/auto-update.sh`, directly after
`au_bump_release`. Required behaviour:

- Arguments: `--name`, `--file`, `--version`, `--attr`, `--url-template`. All required.
- Return 1 with a message on an empty or `null` version, as `au_bump_release` does.
- Return 0 without writing when `jq -r .version "$file"` equals the new version.
- For each key of `.assets`, build the URL from the template by replacing
  `{version}` and `{asset}`, call `au_prefetch_sri`, and check the result with
  `au_require_sri`. On any failure return 1 and leave the file untouched.
- Write once: build the new JSON with `jq` into a temp file in the same
  directory, then `mv` it over the pin file. Keep two-space indentation
  (`jq --indent 2`) so diffs stay line-based.
- Then call `au_build "$attr"` and `au_report_change "$name" "$old" "$new"`.

**Verify**: the Updater tests build exits 0.

Replace the body of `scripts/update-hk.sh` after the `cd` line with:

```bash
latest=$(au_latest_github_release jdx/hk)

au_bump_json_pin --name hk --file pkgs/hk-bin.sources.json --version "$latest" \
  --attr .#martin.hk-bin \
  --url-template 'https://github.com/jdx/hk/releases/download/v{version}/{asset}'
```

In `au_assert_clean`, extend the empty-hash pattern so it also catches JSON:

```bash
  local empty_hash='(hash|sha256|sha512|npmDepsHash|vendorHash|cargoHash) = ""|"hash": ""'
```

**Verify**: the Shell lint command exits 0. The Updater tests and Rolling pins
builds exit 0. If `unit-rolling-pins` fails because it expects a `version`
literal in `pkgs/hk-bin.nix`, that is a STOP condition. Commit (commit 2).

### Step 4: Teach the merge driver the JSON shape

Write the tests first, in `tests/unit/git-merge-pkgnix-test.sh` (created by
plan 006; copy its fixture pattern). Add two cases on a `.json` pin file:

1. Base `1.0.0`, ours `1.1.0`, theirs `1.2.0`, each with its own hashes.
   Expect exit 0 and a result identical to theirs.
2. Base `1.0.0`, ours `1.1.0`, theirs changes an `asset` name. Expect exit 1
   and conflict markers.

**Verify**: case 1 fails before the change.

In `scripts/git-merge-pkgnix.sh`:

1. Add a third alternative to `side_pickable_line` for JSON pin lines:
   `[[:space:]]*"(version|hash)":[[:space:]]*"[^"]*",?`.
2. Make `first_version_literal` fall back to the JSON form when the Nix form
   finds nothing: `sed -nE 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p'`.

In `.gitattributes`, add directly below the existing `pkgs/*.nix` line:

```text
pkgs/*.sources.json merge=pkgnix
```

**Verify**: the Merge driver tests build exits 0. The Shell lint command exits 0.
Commit (commit 3).

## Test plan

- `tests/unit/auto-update-test.sh`: three new cases for `au_bump_json_pin`
  (bump, no-op, failed prefetch). Pattern: the existing `au_set_block_hash` cases.
- `tests/unit/git-merge-pkgnix-test.sh`: two new cases for JSON pins. Pattern:
  the Nix-file cases plan 006 adds.
- The package itself is covered by derivation invariance in Step 2.

## Done criteria

- [ ] Both invariance commands print the paths saved in Step 1
- [ ] `rg -n 'sha256-' pkgs/hk-bin.nix` prints nothing
- [ ] `jq -e '.version and (.assets | length == 3)' pkgs/hk-bin.sources.json` exits 0
- [ ] `rg -c 'tar.gz' scripts/update-hk.sh` prints nothing
- [ ] The Updater tests, Merge driver tests, and Rolling pins builds exit 0
- [ ] `git status --short` lists only in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Plan 006 has not landed. Then `tests/unit/git-merge-pkgnix-test.sh` and its
  check do not exist. Do Steps 1-3 only and report that Step 4 is blocked.
- An invariance command prints a different path after Step 2.
- `unit-rolling-pins` or another check parses `version = "` out of `pkgs/hk-bin.nix`.
- `pkgs/hk-bin.nix` has uncommitted changes when you start. They belong to
  the operator. Ask whether to build on them.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- Decision point after one or two nightly runs: if the `hk` pull requests
  merge cleanly, move the other single-release prebuilt packages the same way,
  one plan per batch. If not, revert commit 1 to 3. The old mechanism is untouched.
- Packages with more than one version literal or an unpacked hash need extra
  fields in the pin file. They are not covered by `au_bump_json_pin` yet.
- A reviewer should check that the temp file for the `jq` write is created
  beside the pin file, so `mv` is atomic.
