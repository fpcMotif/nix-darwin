# Plan 014: `configurations-eval-test.nix` is split by subject, and `mksystem-test.nix` stops repeating it

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- tests/integration/configurations-eval-test.nix tests/unit/mksystem-test.nix tests/default.nix`
> Plans 009, 013, and 018 add or change assertions here. If the file changed,
> re-derive every line range below with
> `rg -n '^  [a-zA-Z]+ =|^  \]|^  \+\+' tests/integration/configurations-eval-test.nix`
> before you start. If the five section names no longer exist, stop and report.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none. Land after plans 009 and 018 if they are in flight, to avoid rebasing a moved file.
- **Category**: tests
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

One 903-line test file holds 104 assertions about a dozen unrelated modules.
A second test file repeats seven of them. This plan moves each section of the
big file into its own file under `tests/integration/configurations-eval/`,
keeps the check name and every assertion unchanged, and deletes the seven
duplicates. The aggregated check must evaluate to the same derivation as before.

## Why this matters

`configurations-eval-test.nix` changed in 30 commits in three months. To
change one module you search a 900-line file for its assertions. The same
skill assertions exist in `mksystem-test.nix`, so one behaviour change breaks
two suites and both copies get edited by hand.

## Current state

Files:

- `tests/integration/configurations-eval-test.nix` — 903 lines. Wired as the
  check `integration-configurations-eval` in `tests/default.nix:443-456`.
- `tests/unit/mksystem-test.nix` — 170 lines, check `unit-mksystem`.
- `tests/lib/assertions.nix` — `assertTest name condition message` and
  `testSuite suiteName tests`.

The check name `integration-configurations-eval` is referenced by
`.github/workflows/auto-update.yml`, `docs/workspace-backends.md`, ADR-0019,
ADR-0020, and one skill. **Do not rename it.**

Structure of `tests/integration/configurations-eval-test.nix` today:

| Lines | Binding | Content |
|---|---|---|
| 1-9 | function header | arguments, including `evalScope ? "auto"` |
| 11-50 | shared `let` bindings | `helpers`, `guideCatalog`, `guideTargets`, `user`, `selectedScope`, `darwinConfiguration`, `darwinConfig`, `darwinSystem`, `darwinHome`, `x230Configuration`, `vmConfiguration`, `x230Config`, `vmConfig`, `x230Home`, `vmHome`, `evalsOk`, `toplevelEvaluatesOnNative`, `hasPackage`, `darwinDojjo`, `darwinDojjoHome` |
| 52-161 | `agentSurfaceChecks = [ ... ];` | a list |
| 163-198 | `workspaceBackendChecks = [ ... ];` | a list |
| 200-590 | `homeChecks = prefix: homeConfig: expectedHomeDirectory: let ... in [ ... ];` | a function that returns a list |
| 592-852 | `darwinChecks = [ ... ] ++ workspaceBackendChecks ++ agentSurfaceChecks ++ (homeChecks "darwin" darwinHome "/Users/${user}");` | a list |
| 854-897 | `nixosChecks = [ ... ] ++ (homeChecks "x230" ...) ++ (homeChecks "vm-aarch64-utm" ...);` | a list |
| 899-903 | `selectedChecks` and the `testSuite` call | |

Lines 1-9 today:

```nix
{ pkgs
, lib
, evalScope ? "auto"
, darwinConfigurationInput ? null
, darwinDojjoConfigurationInput ? null
, x230ConfigurationInput ? null
, vmConfigurationInput ? null
, ...
}:
```

Lines 16-20 today:

```nix
  user = "martinfan";
  selectedScope =
    if evalScope == "auto" then
      (if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "nixos")
    else evalScope;
```

Lines 899-903 today:

```nix
  selectedChecks = if selectedScope == "darwin" then darwinChecks else
  if selectedScope == "nixos" then nixosChecks
  else darwinChecks ++ nixosChecks;
in
helpers.testSuite "configurations-eval" selectedChecks
```

`tests/default.nix:443-456` always passes `evalScope = "darwin"` or
`evalScope = "nixos"`. The `"auto"` default and the final `else` branch can
never run.

The seven duplicated assertions in `tests/unit/mksystem-test.nix:59-97`, by name:

```text
grill-with-docs-skill-enabled
grill-me-skill-disabled
git-workflow-skill-removed
pi-skill-target-configured
factory-skill-target-configured
crush-skill-target-configured
opencode-skill-target-configured
```

Their twins in `configurations-eval-test.nix` (inside `homeChecks`, so they
run for the darwin host and both Linux hosts):

```text
${prefix}-agent-skills-prefers-grill-with-docs      (line 383)
${prefix}-agent-skills-removes-git-workflow         (line 396)
${prefix}-agent-skills-crush-target                 (line 465)
${prefix}-agent-skills-factory-target               (line 469)
${prefix}-agent-skills-opencode-target              (line 473)
${prefix}-agent-skills-pi-target                    (line 477)
```

The first twin covers both `grill-with-docs` and `grill-me`.

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Move every comment together with the code it describes, word for word. Add none.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.

## Commands you will need

Run from the repo root, on the macOS host.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#checks.aarch64-darwin.integration-configurations-eval.drvPath'` | one `/nix/store/...drv` path |
| Case count | `nix eval '.#checks.aarch64-darwin.integration-configurations-eval.tests' --apply builtins.length` | a number |
| Build | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| mksystem | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-mksystem'` | exit 0 |
| Format | `nix fmt -- --check tests/integration tests/unit/mksystem-test.nix` | exit 0 |
| Lint | `nix develop --command deadnix --fail tests/integration tests/unit/mksystem-test.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `tests/integration/configurations-eval-test.nix`
- `tests/integration/configurations-eval/agent-surface.nix` (create)
- `tests/integration/configurations-eval/workspace-backend.nix` (create)
- `tests/integration/configurations-eval/home.nix` (create)
- `tests/integration/configurations-eval/darwin.nix` (create)
- `tests/integration/configurations-eval/nixos.nix` (create)
- `tests/unit/mksystem-test.nix`

**Out of scope** (do NOT touch):

- `tests/default.nix`. The check name and its arguments stay.
- `tests/lib/assertions.nix`. Merging 104 derivations into one is a separate change.
- The text of any assertion: name, condition, or message.
- `tests/README.md`. No check is added or removed.
- Splitting `homeChecks` further by subject. It stays one file in this plan.

## Git workflow

- Branch: `advisor/014-split-configurations-eval-test-by-subject`.
- Two commits:
  1. `test: split configurations-eval-test.nix into one file per subject`
  2. `test(mksystem): drop skill assertions the host eval suite already makes`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baselines

Run the Invariance command and save the output as `EVAL_BEFORE`.
Run the Case count command and save the number as `COUNT_BEFORE`.

### Step 2: Move the five sections into part files

Each part file is a function of one argument, `ctx`. It starts with an
explicit `inherit (ctx)` list and returns what the original binding held.

Template for a part that is a list:

```nix
ctx:

let
  inherit (ctx) helpers lib;
in
[
  # the list elements, moved verbatim
]
```

Template for `home.nix`, which is a function:

```nix
ctx:

let
  inherit (ctx) helpers lib;
in
prefix: homeConfig: expectedHomeDirectory:
let
  # the inner let bindings, moved verbatim
in
[
  # the list elements, moved verbatim
]
```

Do this for each row:

| New file | Take from the original | Returns |
|---|---|---|
| `configurations-eval/agent-surface.nix` | the elements of `agentSurfaceChecks` | a list |
| `configurations-eval/workspace-backend.nix` | the elements of `workspaceBackendChecks` | a list |
| `configurations-eval/home.nix` | the whole `homeChecks` function | a function |
| `configurations-eval/darwin.nix` | the bracketed elements of `darwinChecks` only, not the `++` tail | a list |
| `configurations-eval/nixos.nix` | the bracketed elements of `nixosChecks` only, not the `++` tail | a list |

To build each `inherit (ctx)` list: start with `helpers lib`, then run the
Invariance command. Nix prints `error: undefined variable 'NAME'` for one
missing name at a time. Add that name to the list and run again. Repeat until
the command prints a path. Every name you add must be one of the shared
bindings in lines 11-50, or `pkgs`, or `homeChecks`.

Path literals inside a moved section gain one `../`. For example
`../../modules/home/x` becomes `../../../modules/home/x`. Find them with
`rg -n '\.\./' tests/integration/configurations-eval/`.

### Step 3: Turn the original file into the aggregator

In `tests/integration/configurations-eval-test.nix`:

1. Keep lines 1-50 (header and shared bindings).
2. Replace the five section bindings with:

   ```nix
     ctx = {
       inherit pkgs lib helpers guideCatalog guideTargets user
         darwinConfiguration darwinConfig darwinSystem darwinHome
         x230Configuration vmConfiguration x230Config vmConfig x230Home vmHome
         evalsOk toplevelEvaluatesOnNative hasPackage darwinDojjo darwinDojjoHome;
     };
     part = file: import file ctx;

     agentSurfaceChecks = part ./configurations-eval/agent-surface.nix;
     workspaceBackendChecks = part ./configurations-eval/workspace-backend.nix;
     homeChecks = part ./configurations-eval/home.nix;

     darwinChecks = part ./configurations-eval/darwin.nix
       ++ workspaceBackendChecks ++ agentSurfaceChecks
       ++ (homeChecks "darwin" darwinHome "/Users/${user}");

     nixosChecks = part ./configurations-eval/nixos.nix
       ++ (homeChecks "x230" x230Home "/home/${user}")
       ++ (homeChecks "vm-aarch64-utm" vmHome "/home/${user}");
   ```

   If a part needs `homeChecks`, pass it with `import file (ctx // { inherit homeChecks; })`.

3. Keep the last five lines for now.

Run `git add -N tests/integration/configurations-eval`.

**Verify**: the Invariance command prints exactly `EVAL_BEFORE`. The Case
count command prints `COUNT_BEFORE`.

### Step 4: Remove the unreachable `auto` scope

1. In the header, change `, evalScope ? "auto"` to `, evalScope`.
2. Replace the `selectedScope` binding (lines 17-20) with nothing, and rename
   every remaining use of `selectedScope` to `evalScope`.
3. Replace the `selectedChecks` binding with:

   ```nix
     selectedChecks = if evalScope == "darwin" then darwinChecks else nixosChecks;
   ```

**Verify**: the Invariance command prints exactly `EVAL_BEFORE`.
`rg -n 'selectedScope|"auto"' tests/integration` prints nothing.
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.integration-configurations-eval'` exits 0.

Commit (commit 1).

### Step 5: Delete the seven duplicates from `mksystem-test.nix`

In `tests/unit/mksystem-test.nix`, delete the seven `helpers.assertTest`
entries named in "Current state" from the `commonChecks` list. Keep
`agent-skills-enabled` and every other entry.

**Verify**: `rg -c 'assertTest' tests/unit/mksystem-test.nix` prints `22`.
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-mksystem'` exits 0.

### Step 6: Lint

**Verify**, both exit 0:

- `nix fmt -- --check tests/integration tests/unit/mksystem-test.nix`
- `nix develop --command deadnix --fail tests/integration tests/unit/mksystem-test.nix`

If `deadnix` reports an unused name in an `inherit (ctx)` list, remove that
name and re-run the Invariance command.

Commit (commit 2).

## Test plan

- No new assertions. This plan moves and deletes.
- The gate for the move is derivation invariance: the aggregated check has the
  same derivation path before and after, so every assertion kept its name,
  condition, message, and order.
- The Linux branch (`evalScope = "nixos"`) cannot be evaluated on macOS. CI
  evaluates it on the pull request. Say so in your report.

## Done criteria

- [ ] The Invariance command prints `EVAL_BEFORE` after Step 4
- [ ] `wc -l tests/integration/configurations-eval-test.nix` reports fewer than 90 lines
- [ ] `rg -c 'assertTest' tests/integration/configurations-eval-test.nix tests/integration/configurations-eval/*.nix` sums to 104 (one `assertTest` lives in the `toplevelEvaluatesOnNative` helper)
- [ ] `rg -c 'assertTest' tests/unit/mksystem-test.nix` prints `22`
- [ ] Both builds in "Commands you will need" exit 0
- [ ] `git status --short` lists only in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The Invariance command prints a different path after Step 3 or Step 4, and
  you cannot find a typo within two attempts. Do not edit assertion text to
  make it match.
- An `undefined variable` error names something that is not in lines 11-50,
  not `pkgs`, and not `homeChecks`.
- The `doc-lock` hook blocks a moved comment.
- A twin listed in "Current state" is missing from the split files. Then do
  not delete its duplicate in Step 5.
- `rg -c 'assertTest' tests/unit/mksystem-test.nix` is not `29` before Step 5.

## Maintenance notes

- New host-level assertions go in the part file for their subject. A new
  subject gets a new part file and one line in the aggregator.
- Follow-up, deferred: split `home.nix` (about 390 lines) by module, and make
  `testSuite` run as one derivation instead of 104.
- `unit-mksystem` now tests only what `lib/mkSystem.nix` owns: its shape, host
  names, users, platforms, and a few package checks.
