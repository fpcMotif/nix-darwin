# Plan 015: `tests/default.nix` holds wiring, and two inline test bodies move to their own files

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- tests/default.nix`
> Plans 006, 009, 010, and 013 each change this file. Line numbers below will
> have moved. Find each entry by its name with
> `rg -n '^  (unit|integration|smoke)[a-z-]* =' tests/default.nix`.
> If an entry named below no longer exists, stop and report.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW
- **Depends on**: 014 (same test tree; land 014 first)
- **Category**: tests
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

`tests/default.nix` is the registry of checks, but two entries carry their
whole test body inline, about 210 of its 500 lines. A third entry skips itself
by hand instead of using the file's own `onlyOn` helper. This plan moves the
two bodies into `tests/unit/` and uses `onlyOn` for the third. No check is
renamed, and each check on macOS must evaluate to the same derivation.

## Why this matters

The registry should answer one question: which checks exist and what feeds
them. Today a reader scrolls past 160 lines of guide assertions to find the
next entry. Every other Nix-language test already lives in `tests/unit/` and
is wired with `callTest`.

## Current state

Files:

- `tests/default.nix` — the check registry.
- `tests/unit/*.nix` — Nix-language tests, each a function wired by `callTest`.

Helpers defined at the top of `tests/default.nix`:

```nix
  callTest = path: extraArgs: import path ({ inherit inputs system pkgs lib self; } // extraArgs);
```

```nix
  onlyOn = platform: name: test:
    if (platform == "darwin") == pkgs.stdenv.hostPlatform.isDarwin then test
    else
      pkgs.runCommand "${name}-skipped" { } ''
        echo "Skipping ${platform}-only ${name} on ${system}"
        touch $out
      '';
```

```nix
  darwinDojjo = self.darwinConfigurations."f".extendModules {
    modules = [{ home-manager.users.martinfan.martin.development.workspaceBackend = "dojjo"; }];
  };
```

**Entry 1**, `unit-agent-guides`, lines 109-268 at `534fc39`. It starts:

```nix
  unit-agent-guides =
    let
      docLockGuide = ../modules/home/doc-lock/guide.md;
      guideHosts = startupSections: workspaceGuide: (import ../modules/home/agent-instructions/guides.nix {
        inherit lib pkgs startupSections;
```

and ends:

```nix
      (builtins.attrNames hosts);
    pkgs.runCommand "unit-agent-guides" { } ''
      touch $out
    '';
```

**Entry 2**, `unit-ai-model-routing`, lines 363-413. It starts:

```nix
  unit-ai-model-routing =
    let
      routing = import ../modules/shared/agent-model-routing.nix { inherit lib; };
      policy = pkgs.writeText "agent-model-routing-test.json" (builtins.toJSON routing.policy);
```

and ends:

```nix
    assert !(lib.hasInfix "gpt-5." serializedAdapters);
    pkgs.runCommand "unit-ai-model-routing" { } ''
      ${routingPython}/bin/python3 ${./unit/ai-model-routing-test.py} \
        ${../modules/home/ai-model-routing.py} ${policy}
      touch $out
    '';
```

**Entry 3**, `unit-workspace-backend-lifecycle`, lines 325-359. Its shape:

```nix
  unit-workspace-backend-lifecycle =
    if system == "aarch64-darwin" then
      let
        user = "martinfan";
        ...
      in
      pkgs.runCommand "unit-workspace-backend-lifecycle"
        { nativeBuildInputs = [ ... ]; }
        ''
          bash ${./unit/workspace-backend-lifecycle-test.sh} \
          ...
          touch $out
        ''
    else
      pkgs.runCommand "unit-workspace-backend-lifecycle-skipped" { } ''
        echo "Skipping the workspace-backend lifecycle test on ${system}; host f is aarch64-darwin"
        touch $out
      '';
```

An existing test file to copy the header style from,
`tests/unit/skill-hygiene-test.nix`, starts with a function header that takes
`{ pkgs, lib, self, ... }:`.

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Move comments word for word with their code. Add none. If the hook blocks a
  moved comment, stop and report.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.

## Commands you will need

Run from the repo root, on the macOS host.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#checks.aarch64-darwin.<name>.drvPath'` | one `/nix/store/...drv` path |
| Build one check | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.<name>'` | exit 0 |
| README guard | `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` | exit 0 |
| Format | `nix fmt -- --check tests` | exit 0 |
| Lint | `nix develop --command deadnix --fail tests` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `tests/default.nix`
- `tests/unit/agent-guides-test.nix` (create)
- `tests/unit/ai-model-routing-test.nix` (create)

**Out of scope** (do NOT touch):

- Any `assert`, its order, or its operands.
- Check names. `tests/README.md` is unchanged.
- `tests/unit/ai-model-routing-test.py` and every other existing test file.
- `unit-zsh-vi-mode`, `unit-comment-lint`, and `unit-doc-lock-extension`.
  They are short and stay inline.

## Git workflow

- Branch: `advisor/015-test-registry-holds-wiring-not-test-bodies`.
- One commit: `test: move the agent-guides and model-routing test bodies out of the registry`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baselines

Run the Invariance command for `unit-agent-guides`, `unit-ai-model-routing`,
and `unit-workspace-backend-lifecycle`. Save the three paths.

### Step 2: Move `unit-agent-guides`

Create `tests/unit/agent-guides-test.nix`:

```nix
{ pkgs, lib, ... }:

let
  # the let bindings of the entry, moved verbatim
in
# the assert chain and the final pkgs.runCommand, moved verbatim
```

Then:

1. Change every path literal that starts with `../modules/` to `../../modules/`.
   Find them with `rg -n '\.\./' tests/unit/agent-guides-test.nix`.
2. If the body uses a name that the header lacks, Nix reports
   `undefined variable 'NAME'`. Add `self`, `inputs`, or `system` to the header
   when one of them is named. Any other name is a STOP condition.
3. In `tests/default.nix`, replace the whole entry with:

   ```nix
     unit-agent-guides = callTest ./unit/agent-guides-test.nix { };
   ```

Run `git add -N tests/unit/agent-guides-test.nix`.

**Verify**: the Invariance command for `unit-agent-guides` prints the saved path.

### Step 3: Move `unit-ai-model-routing`

Create `tests/unit/ai-model-routing-test.nix` the same way, with the header
`{ pkgs, lib, ... }:`. Path changes:

- `../modules/shared/agent-model-routing.nix` becomes `../../modules/shared/agent-model-routing.nix`
- `./unit/ai-model-routing-test.py` becomes `./ai-model-routing-test.py`
- `../modules/home/ai-model-routing.py` becomes `../../modules/home/ai-model-routing.py`

In `tests/default.nix`, replace the whole entry with:

```nix
  unit-ai-model-routing = callTest ./unit/ai-model-routing-test.nix { };
```

Run `git add -N tests/unit/ai-model-routing-test.nix`.

**Verify**: the Invariance command for `unit-ai-model-routing` prints the saved path.

### Step 4: Use `onlyOn` for the lifecycle check

In `tests/default.nix`, change the `unit-workspace-backend-lifecycle` entry to:

```nix
  unit-workspace-backend-lifecycle = onlyOn "darwin" "unit-workspace-backend-lifecycle" (
    let
      # the existing let bindings, unchanged
    in
    pkgs.runCommand "unit-workspace-backend-lifecycle"
      # the existing attribute set and script, unchanged
  );
```

Delete the `if system == "aarch64-darwin" then`, the `else`, and the hand-written
skip derivation. Keep the three comment lines above the entry.

**Verify**: the Invariance command for `unit-workspace-backend-lifecycle`
prints the saved path.

### Step 5: Lint and build

**Verify**, all exit 0:

- `nix fmt -- --check tests`
- `nix develop --command deadnix --fail tests`
- `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'`
- `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-agent-guides' '.#checks.aarch64-darwin.unit-ai-model-routing' '.#checks.aarch64-darwin.unit-workspace-backend-lifecycle'`

## Test plan

- No new test. The gate is derivation invariance for the three checks on macOS.
- On Linux the lifecycle check's skip derivation changes its message text, so
  its Linux derivation path changes. That is expected. CI evaluates it.

## Done criteria

- [ ] The three Invariance commands print the paths saved in Step 1
- [ ] `rg -c 'assert ' tests/default.nix` prints no count (no `assert` left in the registry)
- [ ] `wc -l tests/default.nix` reports at least 190 fewer lines than before Step 2
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` exits 0
- [ ] `git status --short` lists only the three in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A moved body needs a name other than `pkgs`, `lib`, `self`, `inputs`, or `system`.
- An Invariance command prints a different path and one more careful diff of
  the moved text does not explain it.
- `system` has a Darwin value other than `aarch64-darwin` in `flake.nix`
  (`rg -n 'darwin' flake.nix`). Then `onlyOn "darwin"` widens where the
  lifecycle check runs.
- The `doc-lock` hook blocks a moved comment.

## Maintenance notes

- New Nix-language tests go in `tests/unit/<name>-test.nix` and get one
  `callTest` line in the registry.
- Follow-up, deferred: the same move for `unit-zsh-vi-mode`.
