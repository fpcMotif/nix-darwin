# Plan 013: Hosts, tests, and `overlays.default` share one overlay list

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- flake.nix tests/default.nix lib`
> If `flake.nix:132-143`, `flake.nix:183`, or `tests/default.nix:4-8` changed,
> compare the "Current state" excerpts against the live code. On a mismatch,
> treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

The package overlays are written out in three places, and the three disagree.
Hosts use four overlays, tests use one, and the exported `overlays.default`
uses one. This plan moves the list into `lib/overlays.nix` and has all three
read it. The host system must build to the same derivation as before.

## Why this matters

A test can pass against a package set that no host ships. `smoke-build-iets`
already works around this by reaching into the host's own `pkgs`. A flake that
imports `overlays.default` gets a `pkgs.martin` without `traits`,
`iets-classic`, or `crush`. One list removes both problems and the workaround.

## Current state

Files:

- `flake.nix` — defines the host overlay list inline and exports `overlays.default`.
- `tests/default.nix` — builds its own `pkgs` with one overlay.
- `lib/mkSystem.nix` — receives `overlays` as an argument. Not edited.
- `pkgs/default.nix` — the repo overlay (`final: _prev: { ... martin = { ... }; }`). Not edited.

`flake.nix:132-143` today, inside the outputs `let`:

```nix
      overlays = [
        inputs.rust-overlay.overlays.default
        (import ./pkgs)
        (final: prev: {
          martin = prev.martin // {
            traits = final.callPackage ./pkgs/traits.nix { src = inputs.traits; };
            iets-classic = final.callPackage ./pkgs/iets { inherit (inputs) iets; };
            inherit (import inputs.charm-nur { pkgs = final; }) crush;
          };
        })
        inputs.claude-code.overlays.default
      ];
```

`flake.nix:145-147` and `flake.nix:160-165` consume it:

```nix
      mkSystem = import ./lib/mkSystem.nix {
        inherit inputs overlays;
      };
      ...
      pkgsFor = s:
        import nixpkgs {
          system = s;
          inherit overlays;
          config.allowUnfree = true;
        };
```

`flake.nix:181-183` today, inside the outputs attrset:

```nix
      # The repo's own overlay (pkgs.martin.* and friends), reusable by other
      # flakes without re-importing ./pkgs by path.
      overlays.default = import ./pkgs;
```

`tests/default.nix:3-8` today:

```nix
let
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ (import ../pkgs) ];
    config.allowUnfree = true;
  };
```

`tests/default.nix:482-487` today, the workaround:

```nix
  smoke-build-iets = onlyOn "darwin" "smoke-build-iets"
    (pkgs.runCommand "smoke-build-iets" { } ''
      echo "Building iets with pkgs/iets/host-system.patch applied..."
      test -x ${self.darwinConfigurations."f".pkgs.martin.iets-classic}/bin/nix
      touch $out
    '');
```

`lib/` holds one file today, `lib/mkSystem.nix`. It starts with
`{ inputs, overlays }:` and uses `inputs.nixpkgs.lib`. Follow that style.

`tests/unit/overlay-test.nix:6-12` imports `../../pkgs` on its own to test the
bare repo overlay. That is correct and stays.

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments outside docs work. Add
  no comments. Keep the existing comment above `overlays.default` as written.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.
- Never run `just switch`, `just sync`, or `darwin-rebuild`.

## Commands you will need

Run from the repo root, on the macOS host.

| Purpose | Command | Expected on success |
|---|---|---|
| Host invariance | `nix eval --raw '.#darwinConfigurations.f.system.drvPath'` | one `/nix/store/...drv` path |
| Check invariance | `nix eval --json '.#checks.aarch64-darwin' --apply 'cs: builtins.mapAttrs (_: c: c.drvPath) cs'` | a JSON object, one entry per check |
| Exported overlay | `nix eval --json '.#overlays.default' --apply 'o: builtins.isFunction o'` | `true` |
| Format | `nix fmt -- --check flake.nix lib/overlays.nix tests/default.nix` | exit 0 |
| Lint | `nix develop --command statix check . && nix develop --command deadnix --fail flake.nix lib/overlays.nix tests/default.nix` | exit 0 |
| Checks | `just check` | exit 0 |

Both invariance commands evaluate the whole configuration. Each can take a
few minutes. `just check` builds every check and the system without activating it.

## Scope

**In scope** (the only files you may modify):

- `lib/overlays.nix` (create)
- `flake.nix` (the `overlays` binding and the `overlays.default` line)
- `tests/default.nix` (the `pkgs` binding and the `smoke-build-iets` entry)

**Out of scope** (do NOT touch):

- `pkgs/default.nix` and every package file.
- `lib/mkSystem.nix`.
- `tests/unit/overlay-test.nix`. It tests the bare repo overlay by design.
- The `formatter` output at `flake.nix:223-240`. It uses
  `nixpkgs.legacyPackages` on purpose, so formatting never builds the overlays.
- `legacyPackagesFor` at `flake.nix:167-175`.

## Git workflow

- Branch: `advisor/013-one-overlay-list-for-hosts-tests-and-exports`.
- One commit: `refactor(flake): define the overlay list once in lib/overlays.nix`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baselines

Run the Host invariance command. Save the output as `HOST_BEFORE`.
Run the Check invariance command. Save the output to a file outside the repo,
for example `$TMPDIR/checks-before.json`.

### Step 2: Create the shared list

Create `lib/overlays.nix`:

```nix
{ inputs }:

let
  repoPackages = import ../pkgs;

  inputPackages = final: prev: {
    martin = prev.martin // {
      traits = final.callPackage ../pkgs/traits.nix { src = inputs.traits; };
      iets-classic = final.callPackage ../pkgs/iets { inherit (inputs) iets; };
      inherit (import inputs.charm-nur { pkgs = final; }) crush;
    };
  };
in
{
  all = [
    inputs.rust-overlay.overlays.default
    repoPackages
    inputPackages
    inputs.claude-code.overlays.default
  ];

  default = inputs.nixpkgs.lib.composeManyExtensions [ repoPackages inputPackages ];
}
```

Run `git add -N lib/overlays.nix`.

### Step 3: Use it in `flake.nix`

Replace the whole `overlays = [ ... ];` binding (lines 132-143) with:

```nix
      repoOverlays = import ./lib/overlays.nix { inherit inputs; };
      overlays = repoOverlays.all;
```

Change line 183 from `overlays.default = import ./pkgs;` to:

```nix
      overlays.default = repoOverlays.default;
```

**Verify**: the Host invariance command prints exactly `HOST_BEFORE`.

### Step 4: Use it in the tests

In `tests/default.nix`, change the `pkgs` binding to:

```nix
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = (import ../lib/overlays.nix { inherit inputs; }).all;
    config.allowUnfree = true;
  };
```

In the `smoke-build-iets` entry, change
`${self.darwinConfigurations."f".pkgs.martin.iets-classic}` to
`${pkgs.martin.iets-classic}`.

**Verify**: run the Check invariance command and save it as
`$TMPDIR/checks-after.json`. Compare the two files with
`delta $TMPDIR/checks-before.json $TMPDIR/checks-after.json` or `diff`.

Expected: no difference at all. One difference is acceptable: the entry
`smoke-build-iets`. Any other differing entry is a STOP condition.

### Step 5: Lint and run the checks

**Verify**, all exit 0:

- `nix fmt -- --check flake.nix lib/overlays.nix tests/default.nix`
- `nix develop --command statix check .`
- `nix develop --command deadnix --fail flake.nix lib/overlays.nix tests/default.nix`
- `nix eval --json '.#overlays.default' --apply 'o: builtins.isFunction o'` prints `true`
- `just check`

## Test plan

- No new test. The gate is derivation invariance: the host system and every
  check must evaluate to the same derivation path as before.
- The Linux checks cannot be evaluated on macOS. CI evaluates them on the pull
  request. Tell the operator this in your report.

## Done criteria

- [ ] `nix eval --raw '.#darwinConfigurations.f.system.drvPath'` equals `HOST_BEFORE`
- [ ] The check drvPath maps are equal, or differ only in `smoke-build-iets`
- [ ] `rg -c 'import \./pkgs\)|import \.\./pkgs\)' flake.nix tests/default.nix` prints no counts (no matches)
- [ ] `rg -n 'darwinConfigurations."f".pkgs' tests/default.nix` returns no matches
- [ ] `just check` exits 0
- [ ] `git status --short` lists only the three in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The host drvPath changes after Step 3. The overlay order or content differs
  from the original. Compare your `all` list against the excerpt, in order.
- Any check other than `smoke-build-iets` changes its drvPath after Step 4.
- `nix eval` reports infinite recursion. `composeManyExtensions` is applied to
  the wrong list.
- `statix` or `deadnix` reports a finding in a file you did not edit. Report
  it and leave that file alone.

## Maintenance notes

- A new package that needs a flake input goes in `inputPackages` in
  `lib/overlays.nix`. A package with no flake input goes in `pkgs/default.nix`.
- `overlays.default` now includes `traits`, `iets-classic`, and `crush`. It
  still needs `rust-overlay` applied first by the consumer, because
  `pkgs/default.nix` reads `final.rust-bin`. That was already true.
- A reviewer should compare the order of `all` with the old inline list. Order
  decides which overlay wins.
