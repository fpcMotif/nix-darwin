# Plan 029: A check's prefix says whether it reads a real host, and the registry holds no test bodies

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- tests/default.nix tests/unit/mksystem-test.nix tests/unit/cleanup-legacy-dotfiles-test.sh tests/unit/workspace-backend-lifecycle-test.sh tests/unit/zsh-vi-mode-test.sh tests/README.md`
> Plans 021, 024, 028, 030, and 031 each edit single lines of
> `tests/default.nix` on purpose. Find every entry by its check name, never by
> line number. If one of the three entries quoted under "Current state" has a
> different body, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

Checks are named `unit-…` or `integration-…`, but no document defines the
difference, and three `unit-` checks evaluate the real host configurations.
Three checks also keep their whole body inline in the registry file. This
plan defines the prefixes, renames the three host-reading checks to
`integration-…`, and moves the three inline bodies into their own files. What
each check tests does not change.

## Why this matters

The prefix is the only hint of a check's cost and of what can break it. A
check that evaluates host `f` fails when any module on that host fails, so it
behaves like an integration check whatever its name says. A contributor
adding a check has to guess the bucket. A written rule plus names that follow
it removes the guess.

## The definition this plan introduces

- **unit**: the check never evaluates a host from `self.darwinConfigurations`
  or `self.nixosConfigurations`. It reads source files, runs a script against
  fixtures, or evaluates one module standalone.
- **integration**: the check evaluates at least one real host configuration.
- **smoke**: the check only builds a package and confirms an executable exists.

## Current state

`tests/default.nix` is the check registry. It defines three helpers
(`callTest`, `shellTest`, `onlyOn`) at lines 11-25 and one shared value,
`darwinDojjo`, at lines 29-31:

```nix
  callTest = path: extraArgs: import path ({ inherit inputs system pkgs lib self; } // extraArgs);

  shellTest = name: { script, inputs, args ? [ ] }:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.bash ] ++ inputs; } ''
      bash ${script} ${lib.concatMapStringsSep " " (arg: "${arg}") args}
      touch $out
    '';

  onlyOn = platform: name: test:
    if (platform == "darwin") == pkgs.stdenv.hostPlatform.isDarwin then test
    else
      pkgs.runCommand "${name}-skipped" { } ''
        echo "Skipping ${platform}-only ${name} on ${system}"
        touch $out
      '';

  # Host "f" with the experimental workspace backend, the way its user would
  # select it. Evaluated once and shared by every check that reads it.
  darwinDojjo = self.darwinConfigurations."f".extendModules {
    modules = [{ home-manager.users.martinfan.martin.development.workspaceBackend = "dojjo"; }];
  };
```

The exemplar of an entry that holds only wiring:

```nix
  unit-module-seams = callTest ./unit/module-seams-test.nix { };
```

### Host-reading check 1: `unit-mksystem`

```nix
  unit-mksystem = callTest ./unit/mksystem-test.nix { };
```

`tests/unit/mksystem-test.nix:12-14` evaluates all three hosts:

```nix
  darwinConfig = self.darwinConfigurations."f".config;
  x230Config = self.nixosConfigurations.x230.config;
  vmConfig = self.nixosConfigurations.vm-aarch64-utm.config;
```

Line 4 of that file imports `../lib/assertions.nix`, and line 6 imports
`../../lib/mkSystem.nix`. Both paths stay valid after a move from
`tests/unit/` to `tests/integration/`, because the two directories are siblings.

### Host-reading check 2, with an inline body: `unit-cleanup-legacy-dotfiles`

```nix
  unit-cleanup-legacy-dotfiles = onlyOn "darwin" "unit-cleanup-legacy-dotfiles"
    (shellTest "unit-cleanup-legacy-dotfiles" {
      script = ./unit/cleanup-legacy-dotfiles-test.sh;
      inputs = [ pkgs.coreutils ];
      args = [
        (pkgs.writeText "cleanup-legacy-dotfiles.sh"
          self.darwinConfigurations."f".config.home-manager.users.martinfan.home.activation.cleanupLegacyDotfiles.data)
        "${pkgs.coreutils}/bin/true"
      ];
    });
```

### Host-reading check 3, with an inline body: `unit-workspace-backend-lifecycle`

```nix
  # Drives wt and djo through create, switch, list, remove, hooks, and a
  # backend switch in disposable repositories. It uses the config files and Zsh
  # lines host "f" ships under each backend, so it runs where "f" builds.
  unit-workspace-backend-lifecycle = onlyOn "darwin" "unit-workspace-backend-lifecycle" (
    let
      user = "martinfan";
      worktrunkHome = self.darwinConfigurations.f.config.home-manager.users.${user};
      dojjoHome = darwinDojjo.config.home-manager.users.${user};
      zshSourceLines = home: marker: pkgs.writeText "${marker}-lines"
        (lib.concatMapStrings (line: line + "\n")
          (builtins.filter (lib.hasInfix marker) (lib.splitString "\n" home.programs.zsh.initContent)));
    in
    pkgs.runCommand "unit-workspace-backend-lifecycle"
      {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.git
          pkgs.jq
          pkgs.zsh
          worktrunkHome.programs.jujutsu.package
          worktrunkHome.programs.worktrunk.package
          pkgs.martin.dojjo-bin
        ];
      }
      ''
        bash ${./unit/workspace-backend-lifecycle-test.sh} \
          ${worktrunkHome.xdg.configFile."worktrunk/config.toml".source} \
          ${zshSourceLines worktrunkHome "-worktrunk-init.zsh"} \
          ${dojjoHome.xdg.configFile."dojjo/config.toml".source} \
          ${zshSourceLines dojjoHome "-dojjo-init.zsh"}
        touch $out
      ''
  );
```

`tests/unit/workspace-backend-lifecycle-test.sh:390` prints its own name:

```bash
printf 'PASS unit-workspace-backend-lifecycle\n'
```

### A true unit check with an inline body: `unit-zsh-vi-mode`

```nix
  # Load the rendered zshrc in a sandboxed zsh to verify keymap tables across
  # default, null-dirjump, and disabled search scenarios.
  unit-zsh-vi-mode =
    let
      zshEval = overrides: (import ./lib/zsh-module-eval.nix { inherit pkgs lib; }) overrides;
      mkInit = name: overrides:
        pkgs.writeText "unit-zsh-vi-mode-initContent-${name}"
          (zshEval overrides).programs.zsh.initContent;
      run = scenario: initFile: ''
        SCENARIO=${scenario} bash ${./unit/zsh-vi-mode-test.sh} ${initFile} ${pkgs.fzf}
      '';
    in
    pkgs.runCommand "unit-zsh-vi-mode"
      {
        nativeBuildInputs = [ pkgs.bash pkgs.zsh pkgs.gnugrep ];
      }
      ''
        ${run "default" (mkInit "default" { })}
        ${run "null-dirjump" (mkInit "null-dirjump" { dirJumpNull = true; })}
        ${run "off" (mkInit "off" { searchEnable = false; })}
        touch $out
      '';
```

It evaluates one module standalone and no host. Its name is correct. Only its
body moves.

### Where the three old names appear outside the registry

Measured on 2026-11-27 with
`rg -n 'unit-(mksystem|cleanup-legacy-dotfiles|workspace-backend-lifecycle)|unit/(mksystem-test|cleanup-legacy-dotfiles-test|workspace-backend-lifecycle-test)' --glob '!plans/**' --glob '!references/**' --glob '!tests/default.nix' .`:

- `tests/README.md:15` (layout tree), `:42` (example command), `:71`, `:81`,
  `:102` (rows of the checks table)
- `docs/workspace-backends.md:154`
- `PANIC.md:97` (`tests/unit/mksystem-test.nix`)
- `tests/unit/workspace-backend-lifecycle-test.sh:390` (the `PASS` line)

### The guard that will catch a half-done rename

`unit-tests-readme` (defined at the top of the registry) fails when the checks
table in `tests/README.md` and the registered check names differ. The table
rows look like:

```markdown
| `unit-mksystem`                     | `lib/mkSystem.nix` shape plus current user, host platform, Home Manager, host module, and common package wiring. |
```

`.github/workflows/build.yml` and `just check` read check names from the
flake, so neither needs an edit.

Repo rules that apply:

- A `doc-lock` hook blocks Markdown and comment changes outside docs work.
  This plan edits three Markdown files and moves comments with their code.
  Moving a comment with its code is allowed. If the hook blocks an edit, stop
  and report. The operator then opens docs work.
- Nix sees only files Git tracks. `git mv` stages its result. After creating
  a file, run `git add -N <path>`.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Names | `nix eval --json '.#checks.aarch64-darwin' --apply builtins.attrNames` | a JSON list of check names |
| README guard | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-tests-readme'` | exit 0 |
| Moved checks | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.integration-mksystem' '.#checks.aarch64-darwin.integration-cleanup-legacy-dotfiles' '.#checks.aarch64-darwin.integration-workspace-backend-lifecycle' '.#checks.aarch64-darwin.unit-zsh-vi-mode'` | exit 0 |
| Doc links | `nix build --no-link '.#checks.aarch64-darwin.unit-doc-links'` | exit 0 |
| Linux names | `nix eval --json '.#checks.x86_64-linux' --apply builtins.attrNames` | a JSON list with the same names |
| Format | `nix fmt -- --check tests` | exit 0 |
| Lint | `nix develop --command deadnix --fail tests` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `tests/default.nix` (the four entries named above)
- `tests/unit/mksystem-test.nix` → `tests/integration/mksystem-test.nix` (move)
- `tests/unit/cleanup-legacy-dotfiles-test.sh` → `tests/integration/cleanup-legacy-dotfiles-test.sh` (move)
- `tests/unit/workspace-backend-lifecycle-test.sh` → `tests/integration/workspace-backend-lifecycle-test.sh` (move, and line 390)
- `tests/integration/cleanup-legacy-dotfiles-test.nix` (create)
- `tests/integration/workspace-backend-lifecycle-test.nix` (create)
- `tests/unit/zsh-vi-mode-test.nix` (create)
- `tests/README.md` (lines 15, 42, 71, 81, 102, and one new section)
- `docs/workspace-backends.md` (line 154)
- `PANIC.md` (line 97)

**Out of scope** (do NOT touch):

- What any check asserts. No assertion is added, removed, or changed.
- `unit-comment-lint` and `unit-doc-lock-extension`. Their inline bodies are
  four lines each and read no host. Leave them.
- The `smoke-build-*` entries.
- The rest of the layout tree in `tests/README.md`. It omits many files.
  Issue #434 tracks that.
- `tests/unit/zsh-vi-mode-test.sh`. It stays where it is.

## Git workflow

- Branch: `advisor/029-check-prefixes-say-whether-a-check-reads-a-host`.
- Three commits:
  1. `test: move the zsh vi-mode check body out of the registry`
  2. `test: rename the three host-reading unit checks to integration`
  3. `docs(tests): define the unit, integration, and smoke prefixes`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baseline

Run the Names command and save the list as `NAMES_BEFORE`.
Run `nix eval --raw '.#checks.aarch64-darwin.unit-zsh-vi-mode.drvPath'` and
save the output as `ZSH_BEFORE`.

### Step 2: Move the `unit-zsh-vi-mode` body

1. Create `tests/unit/zsh-vi-mode-test.nix`:

   ```nix
   { pkgs, lib, ... }:

   let
     zshEval = overrides: (import ../lib/zsh-module-eval.nix { inherit pkgs lib; }) overrides;
     mkInit = name: overrides:
       pkgs.writeText "unit-zsh-vi-mode-initContent-${name}"
         (zshEval overrides).programs.zsh.initContent;
     run = scenario: initFile: ''
       SCENARIO=${scenario} bash ${./zsh-vi-mode-test.sh} ${initFile} ${pkgs.fzf}
     '';
   in
   pkgs.runCommand "unit-zsh-vi-mode"
   {
     nativeBuildInputs = [ pkgs.bash pkgs.zsh pkgs.gnugrep ];
   }
     ''
       ${run "default" (mkInit "default" { })}
       ${run "null-dirjump" (mkInit "null-dirjump" { dirJumpNull = true; })}
       ${run "off" (mkInit "off" { searchEnable = false; })}
       touch $out
     ''
   ```

   The two import paths changed because the file is one directory deeper:
   `./lib/` became `../lib/`, and `./unit/zsh-vi-mode-test.sh` became
   `./zsh-vi-mode-test.sh`.
2. Run `git add -N tests/unit/zsh-vi-mode-test.nix`, then
   `nix fmt -- tests/unit/zsh-vi-mode-test.nix`.
3. In `tests/default.nix`, replace the whole `unit-zsh-vi-mode = let ... '';`
   entry with one line. Keep the two-line comment above it:

   ```nix
     unit-zsh-vi-mode = callTest ./unit/zsh-vi-mode-test.nix { };
   ```

**Verify**: `nix eval --raw '.#checks.aarch64-darwin.unit-zsh-vi-mode.drvPath'`
prints `ZSH_BEFORE` exactly. The move changed no build. Commit (commit 1).

### Step 3: Move and rename the three host-reading checks

1. Move the files:
   - `git mv tests/unit/mksystem-test.nix tests/integration/mksystem-test.nix`
   - `git mv tests/unit/cleanup-legacy-dotfiles-test.sh tests/integration/cleanup-legacy-dotfiles-test.sh`
   - `git mv tests/unit/workspace-backend-lifecycle-test.sh tests/integration/workspace-backend-lifecycle-test.sh`
2. In `tests/integration/workspace-backend-lifecycle-test.sh`, change the last
   `printf` to `printf 'PASS integration-workspace-backend-lifecycle\n'`.
3. Create `tests/integration/cleanup-legacy-dotfiles-test.nix`:

   ```nix
   { pkgs, self, shellTest, ... }:

   shellTest "integration-cleanup-legacy-dotfiles" {
     script = ./cleanup-legacy-dotfiles-test.sh;
     inputs = [ pkgs.coreutils ];
     args = [
       (pkgs.writeText "cleanup-legacy-dotfiles.sh"
         self.darwinConfigurations."f".config.home-manager.users.martinfan.home.activation.cleanupLegacyDotfiles.data)
       "${pkgs.coreutils}/bin/true"
     ];
   }
   ```

4. Create `tests/integration/workspace-backend-lifecycle-test.nix`:

   ```nix
   { pkgs, lib, self, darwinDojjo, ... }:

   let
     user = "martinfan";
     worktrunkHome = self.darwinConfigurations.f.config.home-manager.users.${user};
     dojjoHome = darwinDojjo.config.home-manager.users.${user};
     zshSourceLines = home: marker: pkgs.writeText "${marker}-lines"
       (lib.concatMapStrings (line: line + "\n")
         (builtins.filter (lib.hasInfix marker) (lib.splitString "\n" home.programs.zsh.initContent)));
   in
   pkgs.runCommand "integration-workspace-backend-lifecycle"
   {
     nativeBuildInputs = [
       pkgs.bash
       pkgs.git
       pkgs.jq
       pkgs.zsh
       worktrunkHome.programs.jujutsu.package
       worktrunkHome.programs.worktrunk.package
       pkgs.martin.dojjo-bin
     ];
   }
     ''
       bash ${./workspace-backend-lifecycle-test.sh} \
         ${worktrunkHome.xdg.configFile."worktrunk/config.toml".source} \
         ${zshSourceLines worktrunkHome "-worktrunk-init.zsh"} \
         ${dojjoHome.xdg.configFile."dojjo/config.toml".source} \
         ${zshSourceLines dojjoHome "-dojjo-init.zsh"}
       touch $out
     ''
   ```

5. Run `git add -N` on both new files, then `nix fmt -- tests/integration`.
6. In `tests/default.nix`:
   - Delete the `unit-mksystem` line.
   - Delete the whole `unit-cleanup-legacy-dotfiles` entry.
   - Delete the whole `unit-workspace-backend-lifecycle` entry. Keep its
     three-line comment for the next item.
   - Under the `# Integration tests` comment, after the
     `integration-configurations-eval` entry, add:

     ```nix
       integration-mksystem = callTest ./integration/mksystem-test.nix { };

       integration-cleanup-legacy-dotfiles = onlyOn "darwin" "integration-cleanup-legacy-dotfiles"
         (callTest ./integration/cleanup-legacy-dotfiles-test.nix { inherit shellTest; });

       # Drives wt and djo through create, switch, list, remove, hooks, and a
       # backend switch in disposable repositories. It uses the config files and Zsh
       # lines host "f" ships under each backend, so it runs where "f" builds.
       integration-workspace-backend-lifecycle = onlyOn "darwin" "integration-workspace-backend-lifecycle"
         (callTest ./integration/workspace-backend-lifecycle-test.nix { inherit darwinDojjo; });
     ```

**Verify**: run the README guard command now, before editing the README. It
fails, and its log names the three new check names as missing from the table
and the three old names as unregistered. This is the guard going red. If it
passes, that is a STOP condition.

### Step 4: Update the three documents

1. `tests/README.md`:
   - Line 15: change the tree line for `mksystem-test.nix` so it sits under
     `integration/`, next to the `configurations-eval-test.nix` line. Keep
     its trailing comment text.
   - Line 42: change `unit-mksystem` to `integration-mksystem`.
   - In the checks table, rename the first cell of three rows:
     `unit-mksystem` → `integration-mksystem`,
     `unit-cleanup-legacy-dotfiles` → `integration-cleanup-legacy-dotfiles`,
     `unit-workspace-backend-lifecycle` → `integration-workspace-backend-lifecycle`.
     Keep each description. Move the three rows so they sit with the other
     `integration-` rows.
   - Add a section directly above `## What each test does`:

     ```markdown
     ## Check prefixes

     - `unit-`: the check never evaluates a host from
       `self.darwinConfigurations` or `self.nixosConfigurations`. It reads
       source files, runs a script against fixtures, or evaluates one module
       standalone.
     - `integration-`: the check evaluates at least one real host configuration.
     - `smoke-`: the check builds a package and confirms an executable exists.

     A `.nix` or `.sh` test file lives in `tests/unit/` or
     `tests/integration/` to match its check's prefix. `tests/default.nix`
     holds one wiring line per check and no test body.
     ```

2. `docs/workspace-backends.md` line 154: change
   `unit-workspace-backend-lifecycle` to `integration-workspace-backend-lifecycle`.
3. `PANIC.md` line 97: change `tests/unit/mksystem-test.nix` to
   `tests/integration/mksystem-test.nix`. A rewrite of `PANIC.md` was in
   progress when this plan was written. If the file no longer names
   `mksystem-test.nix`, skip this item.

**Verify**: the README guard, Moved checks, Doc links, Format, and Lint
commands exit 0. Commit (commits 2 and 3: the code and file moves in commit 2,
the three Markdown files in commit 3).

### Step 5: Confirm the check set

Run the Names command and save the list as `NAMES_AFTER`.

**Verify**: `NAMES_AFTER` has the same length as `NAMES_BEFORE`. It differs
in exactly three names, each with `unit-` replaced by `integration-`. Run the
Linux names command and confirm it lists the same names as `NAMES_AFTER`.

Then run the rename search from "Current state".

**Verify**: it prints nothing.

## Test plan

- No new check. This plan moves and renames existing ones.
- `unit-tests-readme` is the guard for the rename. Step 3 watches it fail
  with the old README and Step 4 watches it pass.
- Step 2 proves by derivation path that moving a body out of the registry
  changes nothing about the check.
- The three renamed checks have new derivation names, so they rebuild once.
  The Moved checks command runs them.

## Done criteria

- [ ] `rg -n 'self\.(darwin|nixos)Configurations' tests/unit` returns no matches
- [ ] `rg -n 'unit-(mksystem|cleanup-legacy-dotfiles|workspace-backend-lifecycle)' --glob '!plans/**' --glob '!references/**' .` returns no matches
- [ ] `rg -n '^## Check prefixes' tests/README.md` prints one line
- [ ] The Moved checks command exits 0
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` exits 0
- [ ] Step 5 confirmed the check count is unchanged
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Another file in `tests/unit/` evaluates a real host. Check before Step 3
  with `rg -ln 'self\.(darwin|nixos)Configurations' tests/unit`. On
  2026-11-27 it printed only `tests/unit/mksystem-test.nix`. A new hit needs
  the maintainer's decision, not a silent rename.
- `ZSH_BEFORE` differs after Step 2.
- The README guard passes in Step 3 before the README is edited.
- A workflow, recipe, or hook names one of the three old checks by hand.
  Check with `rg -n 'unit-(mksystem|cleanup-legacy-dotfiles|workspace-backend-lifecycle)' .github justfile hk.pkl`.
  On 2026-11-27 it printed nothing.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- Branch protection or required status checks in GitHub name CI jobs, not
  flake checks, so the rename needs no repository setting change. If that is
  ever configured per check, update it with the rename.
- Two inline bodies remain in the registry on purpose: `unit-comment-lint`
  and `unit-doc-lock-extension`. Each is a four-line command with no host
  read. Move them only if they grow.
- Reviewer: compare the two new `.nix` files against the deleted inline
  bodies line by line. The only intended differences are the derivation
  names and the script paths.
