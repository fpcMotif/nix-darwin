# Plan 023: Homebrew is removed from the config, and Crush shows the model names it routes to

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- modules/darwin/default.nix modules/darwin/brew-variants.nix modules/home/session.nix modules/home/crush.nix modules/shared/agent-model-routing.nix tests/integration/configurations-eval/darwin.nix`
> If any of these changed, compare the "Current state" excerpts against the
> live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27. Part A was rewritten the
  same day: the maintainer decided Homebrew is banned, not kept as a switch.

## At a glance

The repo never uses Homebrew, but it still carries a Homebrew "emergency
switch": a module, a second line that forces the switch off, a test, and an
environment variable. The Crush module also hardcodes three model display
names that no longer match the model ids beside them. This plan deletes every
Homebrew piece and derives the Crush names from the ids. The built system
stays the same apart from one removed environment variable.

## Why this matters

A policy of "no Homebrew" and an option named `homebrew.enable` contradict
each other. A reader who finds the option assumes Homebrew is a supported
path. The switch is also broken: turning it on fails to evaluate. In Crush,
the model picker shows "GPT-5.6 Terra" for the id `gpt-6-astra`, so the name
on screen is not the model that answers.

## Current state

### A. The Homebrew pieces

Measured on 2026-11-27 with
`rg -n -i 'homebrew|brew' --glob '!plans/**' --glob '!references/**' --glob '!flake.lock' --glob '!*.md' .`.
It printed lines in five files.

1. `modules/darwin/brew-variants.nix` (whole file, 24 lines) declares the
   switch and wires it to nix-darwin's own `homebrew` option:

   ```nix
   { config, lib, ... }:

   let
     cfg = config.martin.brew;
   in
   {
     options.martin.brew = {
       homebrew.enable = lib.mkEnableOption "Homebrew as a dormant emergency scaffold; prefer pure Nix/custom derivations";
     };

     config = {
       warnings = lib.optionals cfg.homebrew.enable [
         "martin.brew.homebrew.enable is an emergency scaffold. Prefer pure Nix/custom derivations; never use Homebrew cleanup = zap."
       ];

       homebrew = lib.mkIf cfg.homebrew.enable {
         enable = true;
         onActivation.cleanup = "none";
         casks = [ ];
       };
     };
   }
   ```

2. `modules/darwin/default.nix:1-11` forces the switch off and imports the module:

   ```nix
   { ... }:

   {
     # Homebrew is kept as an emergency, opt-in scaffold.
     martin.brew.homebrew.enable = false;

     imports = [
       ./auto-switch.nix
       ./baseline-activation.nix
       ./background-services.nix
       ./brew-variants.nix
   ```

   Because line 5 is a normal-priority definition, a host that sets the
   switch to `true` gets a "conflicting definition values" error. The switch
   cannot be turned on.

3. `tests/integration/configurations-eval/darwin.nix:255-257` asserts the switch:

   ```nix
     (helpers.assertTest "darwin-brew-default-disabled"
       (darwinConfig.martin.brew.homebrew.enable == false)
       "Homebrew emergency scaffold should remain disabled by default")
   ```

4. `modules/home/session.nix:53` sets a variable only Homebrew reads:

   ```nix
       HOMEBREW_NO_ANALYTICS = "1";
   ```

   It sits between two blank lines inside `home.sessionVariables`.

5. `scripts/verify-session-path.sh:378` mentions Homebrew in a comment about
   release banners. It stays. It describes other people's builds.

nix-darwin itself declares the option `homebrew.enable`, default `false`.
On 2026-11-27 `nix eval '.#darwinConfigurations.f.config.homebrew.enable'`
printed `false`. With the scaffold gone, that option keeps its default, so
the built system does not change.

Two docs state the old policy:

- `AGENTS.md`, in the "Pure Nix first" bullet: `Homebrew stays off by default.`
- `docs/adr/0005-dropbox-installed-natively-not-nix-vendored.md:10`:
  `Rejected: Homebrew stays off by default, and Dropbox's own updater already manages the bundle after installation.`

Two skills mention Homebrew to describe a machine without it:
`modules/home/skills/personal/qmd-nix-darwin-setup/SKILL.md` and
`modules/home/skills/personal/lark-cli-setup/SKILL.md`. They stay.

### B. The Crush model names

`modules/home/crush.nix:5-7` and `:36-40`:

```nix
  reasoningModel = id: name: {
    inherit id name;
    cost_per_1m_in = 0;
```

```nix
      models = [
        (reasoningModel (routing.modelId "general") "GPT-5.6 Terra (ChatGPT subscription)")
        (reasoningModel (routing.modelId "economy") "GPT-5.6 Luna (ChatGPT subscription)")
        (reasoningModel (routing.modelId "search") "GPT-5.3 Codex Spark (ChatGPT subscription)")
      ];
```

`modules/shared/agent-model-routing.nix:4-17` holds the ids those calls return:

```nix
  models = {
    astra = {
      provider = "openai-codex";
      id = "gpt-6-astra";
    };
    sol = {
      provider = "openai-codex";
      id = "gpt-6-sol";
    };
    luna = {
      provider = "openai-codex";
      id = "gpt-6-luna";
    };
  };
```

The same file maps the jobs: `general` uses `astra`, `economy` uses `luna`,
`search` uses `sol`. So Crush shows "GPT-5.6 Terra" for `gpt-6-astra` and
"GPT-5.3 Codex Spark" for `gpt-6-sol`.

Repo rules that apply:

- A `doc-lock` hook blocks Markdown and comment changes outside docs work.
  Step 2 deletes one comment together with its code, which the hook allows.
  Step 5 edits two Markdown files. If the hook blocks an edit, stop and
  report. The operator then opens docs work.
- Use the simplest direct change. Do not add a display-name table to
  `agent-model-routing.nix`. That file feeds five adapters and a JSON policy.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| System | `nix eval --raw '.#darwinConfigurations.f.config.system.build.toplevel.drvPath'` | prints one `.drv` path |
| Homebrew off | `nix eval '.#darwinConfigurations.f.config.homebrew.enable'` | prints `false` |
| Host checks | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| Routing check | `nix build --no-link '.#checks.aarch64-darwin.unit-ai-model-routing'` | exit 0 |
| Doc links | `nix build --no-link '.#checks.aarch64-darwin.unit-doc-links'` | exit 0 |
| Format | `nix fmt -- --check modules/darwin modules/home/crush.nix modules/home/session.nix tests/integration` | exit 0 |
| Lint | `nix develop --command deadnix --fail modules/home/crush.nix` | exit 0 |

The search for leftovers, used in several steps:

```bash
rg -n -i 'homebrew|brew' --glob '!plans/**' --glob '!references/**' --glob '!flake.lock' --glob '!*.md' .
```

## Scope

**In scope** (the only files you may modify):

- `modules/darwin/brew-variants.nix` (delete)
- `modules/darwin/default.nix` (lines 4-5, the blank line after them, and the import line)
- `tests/integration/configurations-eval/darwin.nix` (the one assertion)
- `modules/home/session.nix` (the one variable and one blank line)
- `AGENTS.md` (one sentence)
- `docs/adr/0005-dropbox-installed-natively-not-nix-vendored.md` (one clause)
- `modules/home/crush.nix` (the `reasoningModel` helper and its three calls)

**Out of scope** (do NOT touch):

- `scripts/verify-session-path.sh`.
- The two skills that mention Homebrew.
- `modules/shared/agent-model-routing.nix`.
- Any other doc that names models. Issue #426 tracks that.
- Any Homebrew install on the machine itself. This plan changes the config
  only. It does not uninstall anything.

## Git workflow

- Branch: `advisor/023-fix-two-one-line-module-defects`.
- Four commits:
  1. `refactor(darwin): remove the Homebrew scaffold`
  2. `chore(session): drop the Homebrew analytics variable`
  3. `docs: state that the repo does not use Homebrew`
  4. `fix(crush): label each model with the id it routes to`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baseline

Run the System command and save its output as `SYSTEM_BEFORE`.
Run the Homebrew off command and confirm it prints `false`.

### Step 2: Remove the scaffold

1. Run `git rm modules/darwin/brew-variants.nix`.
2. In `modules/darwin/default.nix`, delete the comment line
   `# Homebrew is kept as an emergency, opt-in scaffold.`, the line
   `martin.brew.homebrew.enable = false;`, and the blank line after them.
   The file body then starts with `imports = [`.
3. In the same file, delete the line `./brew-variants.nix` from the import list.

**Verify**: the System command prints `SYSTEM_BEFORE` exactly. Removing the
scaffold changed nothing in the built system.

### Step 3: Replace the test

Run the Host checks command first.

**Verify**: it fails, and the log names `martin.brew` as a missing option.
This is the old assertion going red.

Then in `tests/integration/configurations-eval/darwin.nix`, replace the
three-line assertion quoted under "Current state" with:

```nix
  (helpers.assertTest "darwin-homebrew-disabled"
    (darwinConfig.homebrew.enable == false)
    "The repo does not use Homebrew")
```

**Verify**: the Host checks command exits 0. The Homebrew off command prints
`false`. Commit Steps 2 and 3 together (commit 1).

### Step 4: Remove the environment variable

In `modules/home/session.nix`, delete the line `HOMEBREW_NO_ANALYTICS = "1";`
and one of the two blank lines around it, so one blank line remains between
`POWERLINE_NERD_FONTS` and `CDPATH`.

**Verify**: the leftovers search prints only the one comment line in
`scripts/verify-session-path.sh`. The Host checks and Format commands exit 0.
Commit (commit 2).

### Step 5: Update the two docs

1. In `AGENTS.md`, replace the sentence `Homebrew stays off by default.` with
   `This repo does not use Homebrew.`
2. In `docs/adr/0005-dropbox-installed-natively-not-nix-vendored.md`, replace
   `Rejected: Homebrew stays off by default, and` with
   `Rejected: this repo does not use Homebrew, and`.

**Verify**: `rg -n 'off by default' AGENTS.md docs/adr/0005-dropbox-installed-natively-not-nix-vendored.md`
prints nothing. The Doc links command exits 0. Commit (commit 3).

### Step 6: Derive the Crush names from the ids

In `modules/home/crush.nix`:

1. Change the helper so it takes only the id and builds the name from it:

   ```nix
     reasoningModel = id: {
       inherit id;
       name = "${id} (ChatGPT subscription)";
       cost_per_1m_in = 0;
   ```

   Keep every other field of the helper unchanged.
2. Change the three calls to pass only the id:

   ```nix
         models = [
           (reasoningModel (routing.modelId "general"))
           (reasoningModel (routing.modelId "economy"))
           (reasoningModel (routing.modelId "search"))
         ];
   ```

**Verify**: `rg -n 'GPT-5|Terra|Spark' modules/home/crush.nix` prints nothing.
The Routing check, Host checks, Format, and Lint commands exit 0.
Commit (commit 4).

## Test plan

- Step 2 proves by derivation path that removing the scaffold leaves the
  built system unchanged.
- Step 3 watches the old assertion fail, then replaces it with one on
  nix-darwin's own `homebrew.enable` option. That assertion fails if any
  module ever turns Homebrew on.
- Part B has no new test. The names are computed from the ids, so they
  cannot disagree with them.

## Done criteria

- [ ] `test ! -e modules/darwin/brew-variants.nix` exits 0
- [ ] The leftovers search prints one line, in `scripts/verify-session-path.sh`
- [ ] `nix eval '.#darwinConfigurations.f.config.homebrew.enable'` prints `false`
- [ ] The Step 2 invariance check passed
- [ ] `rg -n 'GPT-5|Terra|Spark' modules/home/crush.nix` returns no matches
- [ ] `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval' '.#checks.aarch64-darwin.unit-ai-model-routing' '.#checks.aarch64-darwin.unit-doc-links'` exits 0
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A host file under `hosts/` sets `martin.brew.homebrew.enable` or
  `homebrew.enable`. Check with `rg -n 'homebrew' hosts`. On 2026-11-27 it
  printed nothing.
- The System command output differs from `SYSTEM_BEFORE` in Step 2.
- The leftovers search prints a file this plan does not list.
- A test asserts one of the old Crush display names. Check with
  `rg -n 'ChatGPT subscription' tests`. On 2026-11-27 it printed nothing.
- `routing.modelId` no longer exists in `modules/shared/agent-model-routing.nix`.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- Behaviour change to accept: new shells no longer export
  `HOMEBREW_NO_ANALYTICS`. If a Homebrew install exists on the machine
  outside this config, it may then send analytics. Remove that install by
  hand, or keep the variable by skipping Step 4.
- Behaviour change to accept: the Crush model picker will show
  `gpt-6-astra (ChatGPT subscription)` in place of a marketing name. If the
  maintainer wants marketing names, they belong in `agent-model-routing.nix`
  beside each id, as one field every adapter can read.
- A module file that only lists imports should not set option values. Host
  decisions belong in `hosts/<host>/default.nix`.
