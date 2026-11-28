# Plan 022: Drop the Intel Mac pins that no flake output evaluates

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- pkgs/codex.nix pkgs/droid.nix pkgs/fff-mcp.nix pkgs/zig-dev-bin.nix scripts/update-codex.sh scripts/update-droid.sh scripts/update-fff-mcp.sh tests/unit/auto-update-test.sh flake.nix`
> The nightly updater rewrites `version` and `hash` lines in the four package
> files almost daily. Changed version and hash values are expected. A changed
> *shape* (different attribute names, a missing `x86_64-darwin` block) is a
> STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

Four package files pin a download and a hash for `x86_64-darwin`, but the
flake builds nothing for that system, so those hashes are never checked. This
plan removes the four pins and stops three updaters from downloading the Intel
files every night. Builds for Apple Silicon and Linux keep the same derivations.

## Why this matters

A pinned hash is only worth keeping if something builds with it. An Intel hash
here can be wrong for months and nothing fails. The nightly job also downloads
five Intel archives for no reader. The repo already states the opposite
policy in one updater, so today two policies coexist.

## Current state

`flake.nix:96-100` lists the systems the flake supports:

```nix
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
```

`legacyPackages`, `devShells`, and `formatter` are generated from that list.
At commit `5442cca`, `ARCHITECTURE.md:32` said "Intel Macs are out of scope."
That file may since be deleted. The list above is the evidence that counts.

The stated policy, `scripts/update-zed-nightly.sh:25-26`:

```bash
# flake.nix's supportedSystems skips x86_64-darwin, so an Intel pin would never
# reach CI or any host.
```

The four pins. Hash values change nightly, so they are shown as `...` here.

`pkgs/codex.nix:20-25`:

```nix
    x86_64-darwin = {
      asset = "codex-x86_64-apple-darwin";
      hash = "sha256-...";
      host.asset = "codex-code-mode-host-x86_64-apple-darwin";
      host.hash = "sha256-...";
    };
```

`pkgs/droid.nix:19-22`:

```nix
    "x86_64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-x64-baseline/-/cli-darwin-x64-baseline-${version}.tgz";
      hash = "sha256-...";
    };
```

`pkgs/fff-mcp.nix:16-19`:

```nix
    x86_64-darwin = {
      asset = "fff-mcp-x86_64-apple-darwin";
      hash = "sha256-...";
    };
```

`pkgs/zig-dev-bin.nix:14-17`:

```nix
    "x86_64-darwin" = {
      url = "https://ziglang.org/builds/zig-x86_64-macos-${version}.tar.xz";
      hash = "sha256-...";
    };
```

Each file selects its entry with `sources.${system} or (throw ...)`, so
removing an entry changes nothing for the other systems.

The three updaters that fetch the Intel files:

- `scripts/update-codex.sh:13-18`, a loop over four triples that includes the
  line `  x86_64-apple-darwin \`.
- `scripts/update-droid.sh:11`:

  ```bash
  for pkg in cli-darwin-arm64 cli-darwin-x64-baseline cli-linux-arm64 cli-linux-x64-baseline; do
  ```

- `scripts/update-fff-mcp.sh:17-22`, a loop over four asset names that
  includes the line `  fff-mcp-x86_64-apple-darwin \`.

`pkgs/zig-dev-bin.nix` has no updater script.

One test fixture expects the Intel download. `tests/unit/auto-update-test.sh:466-471`:

```bash
  got_urls=$(sort "$fff_dir/urls"/url.*)
  want_urls='https://github.com/dmtrKovalenko/fff/releases/download/0.11.1-nightly.ab3002a/fff-mcp-aarch64-apple-darwin
https://github.com/dmtrKovalenko/fff/releases/download/0.11.1-nightly.ab3002a/fff-mcp-aarch64-unknown-linux-gnu
https://github.com/dmtrKovalenko/fff/releases/download/0.11.1-nightly.ab3002a/fff-mcp-x86_64-apple-darwin
https://github.com/dmtrKovalenko/fff/releases/download/0.11.1-nightly.ab3002a/fff-mcp-x86_64-unknown-linux-gnu'
  [ "$got_urls" = "$want_urls" ] || fail "fff-mcp prefetched wrong URLs: $got_urls"
```

Repo rules that apply:

- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.
- `pkgs/*.nix` uses a custom Git merge driver. Edit only the lines this plan
  names, so a later nightly bump merges cleanly.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance (home) | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | prints one `.drv` path |
| Invariance (codex) | `nix eval --raw '.#legacyPackages.aarch64-darwin.codex.drvPath'` | prints one `.drv` path |
| Invariance (linux) | `nix eval --raw '.#legacyPackages.x86_64-linux.martin.fff-mcp.drvPath'` | prints one `.drv` path |
| Updater test | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-auto-update'` | exit 0 |
| Leftovers | `rg -n 'x86_64-darwin\|x86_64-apple-darwin\|x86_64-macos\|darwin-x64' pkgs/codex.nix pkgs/droid.nix pkgs/fff-mcp.nix pkgs/zig-dev-bin.nix scripts/update-codex.sh scripts/update-droid.sh scripts/update-fff-mcp.sh` | prints nothing |
| Format | `nix fmt -- --check pkgs/codex.nix pkgs/droid.nix pkgs/fff-mcp.nix pkgs/zig-dev-bin.nix` | exit 0 |

In the table, `\|` stands for a plain `|`. In the Leftovers command the
pattern is `x86_64-darwin|x86_64-apple-darwin|x86_64-macos|darwin-x64`, four
alternatives with no backslash.

## Scope

**In scope** (the only files you may modify):

- `pkgs/codex.nix`, `pkgs/droid.nix`, `pkgs/fff-mcp.nix`, `pkgs/zig-dev-bin.nix` (the `x86_64-darwin` entry of `sources` only)
- `scripts/update-codex.sh`, `scripts/update-droid.sh`, `scripts/update-fff-mcp.sh` (the Intel item of each loop only)
- `tests/unit/auto-update-test.sh` (the one Intel URL line in `want_urls`)

**Out of scope** (do NOT touch):

- `meta.platforms` lists that name `x86_64-darwin` in `pkgs/sf-symbols.nix`,
  `pkgs/squirrel.nix`, `pkgs/hammerspoon.nix`, `pkgs/sf-mono.nix`, and
  `pkgs/drafts-mcp-server.nix`. Those are universal macOS downloads with one
  hash. They carry no Intel-only pin.
- `pkgs/sourcegraph-amp.nix`. It maps systems to npm package names and needs
  its own reading. Report it. Do not edit it.
- `flake.nix`. Do not add `x86_64-darwin` to `supportedSystems`.
- Any `version` or `hash` value.

## Git workflow

- Branch: `advisor/022-drop-the-intel-mac-pins-no-output-evaluates`.
- One commit: `chore(pkgs): drop x86_64-darwin pins no flake output evaluates`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baselines

Run the three Invariance commands. Save the outputs as `HOME_BEFORE`,
`CODEX_BEFORE`, and `LINUX_BEFORE`.

### Step 2: Remove the four pins

In each of the four package files, delete the whole `x86_64-darwin` entry of
`sources`, from its opening line to its closing `};`. Leave the other three
entries exactly as they are.

**Verify**: `rg -c 'x86_64-darwin' pkgs/codex.nix pkgs/droid.nix pkgs/fff-mcp.nix pkgs/zig-dev-bin.nix`
prints nothing. The Format command exits 0.

### Step 3: Stop the three updaters fetching Intel files

1. `scripts/update-codex.sh`: delete the line `  x86_64-apple-darwin \` from
   the `for triple in` loop.
2. `scripts/update-droid.sh`: remove `cli-darwin-x64-baseline` from the `for
   pkg in` list on line 11.
3. `scripts/update-fff-mcp.sh`: delete the line
   `  fff-mcp-x86_64-apple-darwin \` from the `for asset in` loop.

**Verify**: `bash -n scripts/update-codex.sh && bash -n scripts/update-droid.sh && bash -n scripts/update-fff-mcp.sh` exits 0.
The Leftovers command prints nothing.

### Step 4: Watch the fixture go red, then fix it

Run the Updater test command now, before editing the fixture.

**Verify**: it fails, and the log contains `fff-mcp prefetched wrong URLs`.
This proves the fixture measures the updater's download list. If it passes,
that is a STOP condition.

Then, in `tests/unit/auto-update-test.sh`, delete the one line inside
`want_urls` that ends with `fff-mcp-x86_64-apple-darwin`.

**Verify**: the Updater test command exits 0.

### Step 5: Check that no build changed

Run the three Invariance commands again.

**Verify**: each output equals its baseline exactly. Commit.

## Test plan

- No new test. `unit-auto-update` already checks the exact list of URLs the
  `fff-mcp` updater downloads. Step 4 watches it fail with the old list and
  pass with the new one.
- Build invariance on three derivations proves the removal touched no
  supported system.

## Done criteria

- [ ] The Leftovers command prints nothing
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-auto-update'` exits 0
- [ ] The Step 5 invariance checks passed
- [ ] `nix fmt -- --check pkgs/codex.nix pkgs/droid.nix pkgs/fff-mcp.nix pkgs/zig-dev-bin.nix` exits 0
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `flake.nix` `supportedSystems` now contains `x86_64-darwin`. The pins would
  then be live.
- A package file selects its source in a way other than
  `sources.${system} or (throw ...)`.
- The Updater test passes in Step 4 before the fixture edit.
- Any Step 5 invariance check fails.
- `unit-auto-update` fails for a reason other than the `want_urls` list.

## Maintenance notes

- The rule after this plan: a package pins a system only if `supportedSystems`
  in `flake.nix` lists it. A new package or updater must follow it.
- If an Intel Mac is ever supported, add `x86_64-darwin` to
  `supportedSystems` first, then restore the pins. The updaters will then
  need the Intel assets back.
- `pkgs/sourcegraph-amp.nix:12` maps `x86_64-darwin` to an npm package name.
  It was not analysed for this plan.
