# Plan 004: `update-fff-mcp.sh` follows the same release channel and URL shape as the pin

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- scripts/update-fff-mcp.sh pkgs/fff-mcp.nix tests/unit/auto-update-test.sh`
> If any of these files changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding. On a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

The `fff-mcp` pin is a nightly build whose download URL has no `v` prefix. Its
updater script still asks for the latest stable release and hashes `v`-prefixed
URLs. This plan makes the updater read the nightly channel and build the same
URL the package builds. The package file and every other updater stay as they are.

## Why this matters

`scripts/update-fff-mcp.sh` runs every night in CI. Today it finds stable
`0.11.0`, sees that it differs from the pinned `0.11.1-nightly.ab3002a`, and
"bumps" to it. That is a downgrade. The hashes it writes come from
`.../download/v0.11.0/...`, while the package fetches `.../download/0.11.0/...`,
which does not exist. The nightly PR then carries a pin that cannot be fetched.

## Current state

Files:

- `pkgs/fff-mcp.nix` — the package. Holds the version and four per-platform hashes.
- `scripts/update-fff-mcp.sh` — the updater. Wrong channel and wrong URL shape.
- `scripts/lib/auto-update.sh` — shared updater library. Not edited by this plan.
- `tests/unit/auto-update-test.sh` — shell test, wired as the Nix check
  `unit-auto-update` in `tests/default.nix:64-68`. It receives five arguments:
  the library path, `modules/darwin/auto-switch.nix`, `pkgs`, `scripts`, `.github`.

`pkgs/fff-mcp.nix:6-9` today:

```nix
let
  version = "0.11.1-nightly.ab3002a";

  releaseBase = "https://github.com/dmtrKovalenko/fff/releases/download/${version}";
```

`scripts/update-fff-mcp.sh` today (whole file):

```bash
#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release dmtrKovalenko/fff)
base="https://github.com/dmtrKovalenko/fff/releases/download/v${latest}"

assets=()
for asset in \
  fff-mcp-aarch64-apple-darwin \
  fff-mcp-x86_64-apple-darwin \
  fff-mcp-aarch64-unknown-linux-gnu \
  fff-mcp-x86_64-unknown-linux-gnu
do
  assets+=(--asset "${base}/${asset}" "asset = \"${asset}\";")
done

au_bump_release --name fff-mcp --file pkgs/fff-mcp.nix --version "$latest" \
  --attr .#martin.fff-mcp "${assets[@]}"
```

Upstream tag facts, observed on 2026-11-17 with `gh api repos/dmtrKovalenko/fff/releases`:

- Nightly tags look like `0.11.1-nightly.ab3002a`. They have no `v` prefix and
  are marked prerelease.
- A rolling tag named `nightly` also exists. It must never be pinned.
- The latest stable tag is `v0.11.0`.

Library facts you rely on (`scripts/lib/auto-update.sh`):

- `au_github_api URL` prints the JSON body of a GitHub API call.
- `au_latest_github_release REPO` (line 218) reads `/releases/latest`, which is
  the stable channel. Its `prerelease` mode picks the most recently published
  release of any name, so it can return the rolling `nightly` tag. Do not use it here.
- `au_bump_release` returns early when the file's version equals `--version`.

The end of `tests/unit/auto-update-test.sh` today:

```bash
grep -qF 'archive --format=tar' "$auto_switch"
grep -qF 'snapshot=$(mktemp -d' "$auto_switch"
if grep -qF 'git+file://' "$auto_switch"; then
  fail "auto-switch must not ask root Nix to open the user-owned Git repo"
fi

echo "auto-update-test: all assertions passed"
```

The test file defines `fail() { echo "auto-update-test: $*" >&2; exit 1; }` and
the variables `pkgs_dir` (argument 3) and `scripts_dir` (argument 4). Both may be empty.

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work. Add no comments.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Use `rg`, `fd`,
  and `bat -pp -r A:B FILE`.
- The working tree may hold uncommitted pin bumps in other `pkgs/*.nix` files
  and `flake.lock`. Leave them alone.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Unit test, direct | `bash tests/unit/auto-update-test.sh scripts/lib/auto-update.sh modules/darwin/auto-switch.nix pkgs scripts .github` | last line `auto-update-test: all assertions passed` |
| Nix gate | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update'` | exit 0 |
| Syntax | `bash -n scripts/update-fff-mcp.sh` | exit 0, no output |

Never run `just switch`, `just sync`, `just bump-and-switch`, or `darwin-rebuild`.

## Scope

**In scope** (the only files you may modify):

- `scripts/update-fff-mcp.sh`
- `tests/unit/auto-update-test.sh` (insert one block)

**Out of scope** (do NOT touch):

- `pkgs/fff-mcp.nix`. The pin is correct. Running the updater in Step 3 may
  legitimately bump it. That is the only allowed change to it.
- `scripts/lib/auto-update.sh`. Plans 005 and 007 edit it.
- Every other `scripts/update-*.sh`.

## Git workflow

- Branch: `advisor/004-fff-mcp-updater-follows-pinned-nightly`.
- One commit. Style follows the repo, for example
  `fix(crush): take crush from Charm's own repo instead of the NUR aggregate`. Use:
  `fix(fff-mcp): follow the nightly channel the pin uses`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Add the failing test

In `tests/unit/auto-update-test.sh`, insert this block directly above the line
`grep -qF 'archive --format=tar' "$auto_switch"`:

```bash
if [ -n "$pkgs_dir" ] && [ -n "$scripts_dir" ]; then
  nix_tag=$(grep -oE 'releases/download/v?\$\{version\}' "$pkgs_dir/fff-mcp.nix" | head -1)
  sh_tag=$(grep -oE 'releases/download/v?\$\{latest\}' "$scripts_dir/update-fff-mcp.sh" | head -1)
  [ -n "$nix_tag" ] || fail "pkgs/fff-mcp.nix has no releases/download/\${version} URL"
  [ -n "$sh_tag" ] || fail "update-fff-mcp.sh has no releases/download/\${latest} URL"
  [ "${nix_tag%'${version}'}" = "${sh_tag%'${latest}'}" ] \
    || fail "update-fff-mcp.sh hashes '$sh_tag' but pkgs/fff-mcp.nix fetches '$nix_tag'"
  if grep -qF 'au_latest_github_release' "$scripts_dir/update-fff-mcp.sh"; then
    fail "update-fff-mcp.sh must pick a dated nightly tag, not au_latest_github_release"
  fi
fi
```

**Verify**: run the direct unit test command. It must FAIL with
`update-fff-mcp.sh hashes 'releases/download/v${latest}' but pkgs/fff-mcp.nix fetches 'releases/download/${version}'`.

### Step 2: Fix the updater

In `scripts/update-fff-mcp.sh`, replace these two lines:

```bash
latest=$(au_latest_github_release dmtrKovalenko/fff)
base="https://github.com/dmtrKovalenko/fff/releases/download/v${latest}"
```

with:

```bash
latest=$(au_github_api "https://api.github.com/repos/dmtrKovalenko/fff/releases?per_page=30" \
  | jq -r '[.[]
      | select(.draft | not)
      | select(.tag_name | test("^[0-9]+\\.[0-9]+\\.[0-9]+-nightly\\.[0-9a-f]+$"))]
    | sort_by(.published_at) | last | .tag_name // ""')
if [ -z "$latest" ]; then
  echo "fff-mcp: no dated nightly release found" >&2
  exit 1
fi
base="https://github.com/dmtrKovalenko/fff/releases/download/${latest}"
```

Leave the rest of the file unchanged.

**Verify**: `bash -n scripts/update-fff-mcp.sh` exits 0. The direct unit test
command now ends with `auto-update-test: all assertions passed`.

### Step 3: Run the updater once against the network

Run `bash scripts/update-fff-mcp.sh`.

**Verify**: the output is one of these two shapes, and the exit code is 0:

- `fff-mcp already at 0.11.1-nightly.<hash>`
- `fff-mcp  <old> --> <new>` where `<new>` matches `N.N.N-nightly.<hex>`

If it bumped, `git diff pkgs/fff-mcp.nix` must show only the `version` line and
`hash` lines changing. Keep that change in the commit.

### Step 4: Run the Nix gate

**Verify**: `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update'` exits 0.

## Test plan

- New assertions live in `tests/unit/auto-update-test.sh` (Step 1). They cover:
  the updater and the package agree on the `v` prefix, and the updater does not
  use the stable-channel helper.
- Pattern to follow: the `if [ -n "$github_dir" ]; then ... fi` block just
  above the insertion point.
- Verification: the direct unit test command and the Nix gate both pass.

## Done criteria

- [ ] `bash tests/unit/auto-update-test.sh scripts/lib/auto-update.sh modules/darwin/auto-switch.nix pkgs scripts .github` ends with `all assertions passed`
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-auto-update'` exits 0
- [ ] `rg -n 'download/v\$' scripts/update-fff-mcp.sh` returns no matches
- [ ] `rg -n 'au_latest_github_release' scripts/update-fff-mcp.sh` returns no matches
- [ ] `git status --short` lists only the in-scope files, plus `pkgs/fff-mcp.nix` if Step 3 bumped it, plus files that were already modified before you started
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The excerpts in "Current state" do not match the live files.
- Step 3 prints `fff-mcp: no dated nightly release found`. Upstream changed its
  tag scheme. Report the tag names from
  `gh api 'repos/dmtrKovalenko/fff/releases?per_page=10' --jq '.[].tag_name'`.
- Step 3 fails with a download error for any asset. The asset names changed upstream.
- The operator says the pin should track stable releases instead. Then the fix
  is in `pkgs/fff-mcp.nix`, which is out of scope here.

## Maintenance notes

- If upstream ships a stable `0.11.1` and you want it, change the tag filter in
  the updater and the `releaseBase` line in `pkgs/fff-mcp.nix` together. The
  Step 1 test fails if only one side changes.
- Nightly tags share one semver core, so the updater orders them by
  `published_at`, not by version text.
- Plans 005 and 007 append to the same test file. Land them one after another.
