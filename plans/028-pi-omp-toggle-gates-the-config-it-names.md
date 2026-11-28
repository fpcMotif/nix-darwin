# Plan 028: `martin.piOmp.enable` gates the pi and omp config, not only the packages

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- modules/home/pi.nix modules/home/ai-model-routing.nix modules/home/ai-model-routing modules/home/agent-instructions.nix modules/home/agent-instructions/default.nix modules/home/doc-lock/default.nix tests/integration/configurations-eval tests/integration/configurations-eval-test.nix`
> Plan 025 moves two of these files on purpose. See "Current state" for the
> two possible locations. Any other mismatch with the excerpts is a STOP
> condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

The option `martin.piOmp.enable` says it controls "the pi and omp agents",
but it gates only their packages, one shell wrapper, and one launchd job. With
the option off, which is the state of the only active host, every switch still
writes pi and omp settings, installs omp agent files, and links two pi and omp
extensions. This plan puts those three pieces behind the same option. Skill
links and agent guides are not changed.

## Behaviour change to accept

**The maintainer approved this change on 2026-11-27.**

Host `f` does not set `martin.piOmp.enable`, so it is `false` there. After
this plan, the next switch on host `f` will:

- stop running the activation step that rewrites `~/.pi/agent/settings.json`
  and `~/.omp/agent/config.yml`,
- remove the Home Manager links `~/.config/agent-routing/omp.yml`,
  `~/.config/agent-routing/omp-economy.yml`,
  `~/.config/agent-routing/README.md`, and the four files under
  `~/.omp/agent/agents/`,
- remove the links `~/.pi/agent/extensions/doc-lock.ts` and
  `~/.omp/agent/hooks/pre/doc-lock.ts`.

If pi or omp is installed on that machine by other means and should keep this
config, do not run this plan. The alternative is to leave the code alone and
reword the option's description to "the pi and omp packages, the pi shell
wrapper, and the daily pi extension update".

A test changes on purpose. Today
`tests/integration/configurations-eval/home.nix:319-321` requires the three
`agent-routing` files on Darwin unconditionally. After this plan it requires
them only when the option is on.

## Why this matters

A switch named for a feature should turn the feature off. Today it turns off
the binaries and leaves their configuration running, so each switch writes
settings for tools that are not installed. It is also the only per-agent
toggle in the repo, so it is the pattern the next toggle will copy.

## Current state

### The option and what it gates today

`modules/home/pi.nix:22-26`:

```nix
{
  options.martin.piOmp.enable = lib.mkEnableOption "the pi and omp agents, their shell wrappers, and the daily pi extension update";

  config = lib.mkIf (config.martin.piOmp.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    home.packages = [ pkgs.martin.pi-coding-agent pkgs.martin.oh-my-pi ];
    launchd.agents.pi-extension-update = {
```

`modules/home/ai-cli.nix:95` gates the `pi()` shell wrapper:

```nix
  '' + lib.optionalString config.martin.piOmp.enable ''
```

No file under `hosts/` sets the option. `rg -n 'piOmp' hosts` prints nothing.

### Piece 1: the routing activation, not gated

`modules/home/ai-model-routing.nix:8-15` (after plan 025:
`modules/home/ai-model-routing/default.nix`):

```nix
{
  # Pi and OMP own mutable runtime settings. This adapter reasserts only model
  # routing fields from the shared semantic policy and preserves other state.
  home.activation.aiModelRouting = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${python}/bin/python3 ${./ai-model-routing.py} \
      ${policy} ${config.home.homeDirectory}
  '';
}
```

The Python script it runs writes `~/.pi/agent/settings.json`
(`ai-model-routing.py:36`) and `~/.omp/agent/config.yml`
(`ai-model-routing.py:121`). It creates each file when the file is missing.

### Piece 2: the omp files, not gated

`modules/home/agent-instructions.nix:8-28` (after plan 025:
`modules/home/agent-instructions/default.nix`, with `./` in place of
`./agent-instructions/`):

```nix
  darwinFiles = {
    ".codex/fast.config.toml" = toml.generate "codex-fast.config.toml"
      modelRouting.adapters.codex.profiles.fast;
    ".codex/fast-low.config.toml" = toml.generate "codex-fast-low.config.toml"
      modelRouting.adapters.codex.profiles.fast-low;
    ".codex/plan.config.toml" = toml.generate "codex-plan.config.toml"
      modelRouting.adapters.codex.profiles.plan;
    ".codex/deep.config.toml" = toml.generate "codex-deep.config.toml"
      modelRouting.adapters.codex.profiles.deep;
    ".config/agent-routing/omp.yml" = yaml.generate "omp-routing.yml"
      modelRouting.adapters.omp.normal;
    ".config/agent-routing/omp-economy.yml" = yaml.generate "omp-economy.yml"
      modelRouting.adapters.omp.economy;
    ".config/agent-routing/README.md" = ../../config/omp/README.md;
    ".omp/agent/agents/codex-plan-deployer.md" = ./agent-instructions/omp/agent/agents/codex-plan-deployer.md;
    ".omp/agent/agents/codex-spark-worker.md" = ./agent-instructions/omp/agent/agents/codex-spark-worker.md;
    ".omp/agent/agents/designer.md" = ./agent-instructions/omp/agent/agents/designer.md;
    ".omp/agent/agents/oracle.md" = ./agent-instructions/omp/agent/agents/oracle.md;
  };
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  files = guideCatalog.files // lib.optionalAttrs isDarwin darwinFiles;
```

The first four entries are Codex profiles. The last seven are omp files. (If
plan 021 landed, the `README.md` entry has a different source path. Keep
whatever path you find.)

### Piece 3: the pi and omp doc-lock extensions, not gated

`modules/home/doc-lock/default.nix:50-52`, inside `lib.mkIf enabled { ... }`:

```nix
      home.file.".claude/hooks/doc-lock.sh".source = docLockExe;
      home.file.".pi/agent/extensions/doc-lock.ts".source = pkgs.martin.doc-lock-extension;
      home.file.".omp/agent/hooks/pre/doc-lock.ts".source = pkgs.martin.doc-lock-extension;
```

### The test that pins piece 2

`tests/integration/configurations-eval/home.nix:6` gives each assertion the
evaluated home config as `homeConfig`:

```nix
prefix: homeConfig: expectedHomeDirectory:
```

Lines 311-323:

```nix
  (helpers.assertTest "${prefix}-agent-guide-files"
    (lib.all
      (path: builtins.hasAttr path homeData.file && !homeData.file.${path}.force)
      (guideTargets ++ lib.optionals (prefix == "darwin") [
        ".codex/fast.config.toml"
        ".codex/fast-low.config.toml"
        ".codex/plan.config.toml"
        ".codex/deep.config.toml"
        ".config/agent-routing/omp.yml"
        ".config/agent-routing/omp-economy.yml"
        ".config/agent-routing/README.md"
      ]))
    "${prefix} catalog guides and agent profiles must use non-forced Home Manager files")
```

### How tests evaluate host `f` with one option changed

`tests/default.nix:29-31` is the pattern:

```nix
  darwinDojjo = self.darwinConfigurations."f".extendModules {
    modules = [{ home-manager.users.martinfan.martin.development.workspaceBackend = "dojjo"; }];
  };
```

`tests/integration/configurations-eval/darwin.nix` receives `darwinHome` (host
`f`'s home config) through its `ctx` argument, and its assertions use
`helpers.assertTest "<name>" <bool> "<message>"`. Example, lines 268-269:

```nix
    (!darwinHome.martin.piOmp.enable || hasPackage "oh-my-pi" darwinHome.home.packages)
    "Darwin Home Manager packages should include oh-my-pi when martin.piOmp.enable is set")
```

### What stays ungated, and why

- Skill links into `~/.pi/agent/skills` and `~/.omp/agent/...`
  (`modules/home/skill-placement.nix:10-14,59-70`). ADR-0019 makes skill
  visibility own each harness's list, and
  `tests/integration/configurations-eval/darwin.nix:251` asserts a pi skill link.
- The omp guides (`modules/home/agent-instructions/guides.nix:105-112`).
  ADR-0020 says the guide catalog "owns every installed guide" on every system.
- ADR-0010 defers a single `martin.ai.enable` switch for all agents. This
  plan does not add one. It only makes the existing pi and omp switch
  consistent.

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Add no comment. Keep the existing comment above `aiModelRouting`.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Off: activation | `nix eval '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activation' --apply 'a: a ? aiModelRouting'` | see steps |
| Off: omp file | `nix eval '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.file' --apply 'f: f ? ".omp/agent/agents/oracle.md"'` | see steps |
| Off: Codex file | `nix eval '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.file' --apply 'f: f ? ".codex/plan.config.toml"'` | prints `true` |
| Checks | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.integration-configurations-eval' '.#checks.aarch64-darwin.unit-module-seams' '.#checks.aarch64-darwin.unit-mksystem' '.#checks.aarch64-darwin.unit-ai-model-routing'` | exit 0 |
| Linux checks | `nix eval --raw '.#nixosConfigurations.x230.config.system.build.toplevel.drvPath'` | prints one `.drv` path |
| Format | `nix fmt -- --check modules/home tests` | exit 0 |

If plan 029 is DONE in `plans/README.md`, the check `unit-mksystem` is named
`integration-mksystem`. Use that name in the Checks command.

## Scope

**In scope** (the only files you may modify):

- `modules/home/ai-model-routing.nix` (or `modules/home/ai-model-routing/default.nix`)
- `modules/home/agent-instructions.nix` (or `modules/home/agent-instructions/default.nix`)
- `modules/home/doc-lock/default.nix` (lines 51-52)
- `tests/integration/configurations-eval/home.nix` (the `agent-guide-files` assertion)
- `tests/integration/configurations-eval/darwin.nix` (new assertions)
- `tests/integration/configurations-eval-test.nix` and `tests/default.nix` (only to pass one more evaluated host to the part files, if Step 5 needs it)

**Out of scope** (do NOT touch):

- `modules/home/pi.nix` and `modules/home/ai-cli.nix`. They already gate correctly.
- `modules/home/skill-placement.nix`, `modules/home/agent-instructions/guides.nix`,
  and `modules/home/agent-surface.nix`.
- `modules/home/ai-model-routing.py` and the shared routing policy.
- `hosts/darwin/default.nix`. Do not turn the option on.

## Git workflow

- Branch: `advisor/028-pi-omp-toggle-gates-the-config-it-names`.
- One commit: `fix(pi-omp): gate pi and omp config behind martin.piOmp.enable`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Confirm approval and the starting state

Confirm the operator said the maintainer approved "Behaviour change to
accept". If not, stop.

Run the two "Off" commands for the activation and the omp file.

**Verify**: both print `true`. That is the defect: the option is off and both
exist.

### Step 2: Gate the routing activation

In the routing module, wrap the activation value in `lib.mkIf`:

```nix
  home.activation.aiModelRouting = lib.mkIf config.martin.piOmp.enable (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${python}/bin/python3 ${./ai-model-routing.py} \
        ${policy} ${config.home.homeDirectory}
    ''
  );
```

Keep the two comment lines above it unchanged.

**Verify**: the "Off: activation" command prints `false`.

### Step 3: Gate the omp files

In the agent-instructions module:

1. Split `darwinFiles` into two bindings. `codexFiles` holds the four
   `.codex/*.config.toml` entries. `ompFiles` holds the other seven entries.
   Move the entries unchanged.
2. Change the `files` line to:

   ```nix
     files = guideCatalog.files
       // lib.optionalAttrs isDarwin codexFiles
       // lib.optionalAttrs (isDarwin && config.martin.piOmp.enable) ompFiles;
   ```

**Verify**: `rg -n 'darwinFiles' modules/home` prints nothing.
The "Off: omp file" command prints `false`.
The "Off: Codex file" command prints `true`.

### Step 4: Gate the two extensions

In `modules/home/doc-lock/default.nix`, replace lines 51-52 with:

```nix
      home.file.".pi/agent/extensions/doc-lock.ts" = lib.mkIf config.martin.piOmp.enable {
        source = pkgs.martin.doc-lock-extension;
      };
      home.file.".omp/agent/hooks/pre/doc-lock.ts" = lib.mkIf config.martin.piOmp.enable {
        source = pkgs.martin.doc-lock-extension;
      };
```

Leave line 50 (`.claude/hooks/doc-lock.sh`) unchanged.

**Verify**:
`nix eval '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.file' --apply 'f: f ? ".pi/agent/extensions/doc-lock.ts"'`
prints `false`. The same command with `".claude/hooks/doc-lock.sh"` prints `true`.

### Step 5: Update the pinned test and add the on/off assertions

1. Run the Checks command now.

   **Verify**: `integration-configurations-eval` fails, and the log names
   `darwin-agent-guide-files`. This is the old assertion going red. If
   `unit-module-seams` also fails on a pi or omp extension path, that is
   expected: note the assertion name and treat it in item 3.

2. In `tests/integration/configurations-eval/home.nix`, change the list in
   the `agent-guide-files` assertion so the three `agent-routing` paths are
   required only when the option is on:

   ```nix
         (guideTargets ++ lib.optionals (prefix == "darwin") [
           ".codex/fast.config.toml"
           ".codex/fast-low.config.toml"
           ".codex/plan.config.toml"
           ".codex/deep.config.toml"
         ] ++ lib.optionals (prefix == "darwin" && homeConfig.martin.piOmp.enable) [
           ".config/agent-routing/omp.yml"
           ".config/agent-routing/omp-economy.yml"
           ".config/agent-routing/README.md"
         ]))
   ```

3. If `unit-module-seams` failed in item 1, make its failing assertion
   conditional on the option in the same way. Change nothing else in that file.

4. Add an evaluated copy of host `f` with the option on, following the
   `darwinDojjo` pattern in `tests/default.nix:29-31`:

   ```nix
     darwinPiOmp = self.darwinConfigurations."f".extendModules {
       modules = [{ home-manager.users.martinfan.martin.piOmp.enable = true; }];
     };
   ```

   Pass it to `tests/integration/configurations-eval-test.nix` the same way
   `darwinDojjo` is passed, and expose its home config to the part files as
   `darwinPiOmpHome`, the same way `darwinDojjoHome` is exposed in the `ctx`
   set near line 50 of that file.

5. In `tests/integration/configurations-eval/darwin.nix`, add two assertions:

   ```nix
     (helpers.assertTest "darwin-pi-omp-off-installs-no-pi-omp-config"
       (darwinHome.martin.piOmp.enable
         || (!(darwinHome.home.activation ? aiModelRouting)
           && !(darwinHome.home.file ? ".omp/agent/agents/oracle.md")
           && !(darwinHome.home.file ? ".config/agent-routing/omp.yml")
           && !(darwinHome.home.file ? ".pi/agent/extensions/doc-lock.ts")))
       "With martin.piOmp.enable off, no pi or omp routing, agent, or extension file is installed")

     (helpers.assertTest "darwin-pi-omp-on-installs-pi-omp-config"
       (darwinPiOmpHome.home.activation ? aiModelRouting
         && darwinPiOmpHome.home.file ? ".omp/agent/agents/oracle.md"
         && darwinPiOmpHome.home.file ? ".config/agent-routing/omp.yml"
         && darwinPiOmpHome.home.file ? ".pi/agent/extensions/doc-lock.ts")
       "With martin.piOmp.enable on, the pi and omp routing, agent, and extension files are installed")
   ```

   Add `darwinPiOmpHome` to the `inherit (ctx) ...` line at the top of the file.

**Verify**: the Checks command exits 0. The Linux checks command prints a
path. The Format command exits 0.

### Step 6: Watch the new assertions go red

Temporarily remove the `lib.mkIf config.martin.piOmp.enable` wrapper added in
Step 2 and run
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.integration-configurations-eval'`.

**Verify**: it fails, and the log names
`darwin-pi-omp-off-installs-no-pi-omp-config`. Restore the wrapper and confirm
the check passes again. Commit.

## Test plan

- Two new assertions in `tests/integration/configurations-eval/darwin.nix`:
  one for the option off (host `f` as it is), one for the option on (host `f`
  with the option forced on). They cover all three gated pieces.
- Step 5 item 1 watches the old unconditional assertion fail. Step 6 watches
  the new off-assertion fail when a gate is removed.
- Pattern to follow: the existing `piOmp` assertion at
  `tests/integration/configurations-eval/darwin.nix:268-269`.

## Done criteria

- [ ] The "Off: activation" and "Off: omp file" commands print `false`
- [ ] The "Off: Codex file" command prints `true`
- [ ] `rg -n 'darwin-pi-omp-(on|off)' tests/integration/configurations-eval/darwin.nix` prints two lines
- [ ] The Checks command exits 0
- [ ] Step 6 saw the off-assertion fail with the gate removed
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A file under `hosts/` sets `martin.piOmp.enable`. The starting state then
  differs from this plan.
- The agent-instructions module uses `darwinFiles` anywhere other than the
  `files` line.
- A test other than `darwin-agent-guide-files` and one `unit-module-seams`
  assertion fails after Step 4.
- Making `aiModelRouting` conditional breaks `unit-ai-model-routing`. That
  test runs the Python script directly and should not depend on the option.

## Maintenance notes

- After the first switch with this change on host `f`, files that pi or omp
  wrote themselves (`~/.pi/agent/settings.json`, `~/.omp/agent/config.yml`)
  stay on disk. Home Manager removes only the links it placed.
- If a second per-agent toggle is added, gate the same three kinds of thing:
  packages, activation writers, and installed files. ADR-0010 records why
  one switch for all agents is deferred.
- Reviewer: check that `.codex/*.config.toml` still installs with the option
  off. The split of `darwinFiles` is the step most likely to drop an entry.
