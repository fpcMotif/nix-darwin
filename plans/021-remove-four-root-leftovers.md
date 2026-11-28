# Plan 021: Remove four leftovers at the repo root

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- justfile flake.nix scripts/update-crush.sh pkgs/agent-trace.nix tools/agent-trace config .gitignore modules/home/agent-instructions.nix`
> If any of these changed, compare the "Current state" excerpts against the
> live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

Four small things at the top of the repo exist only because of history: a
`just` recipe that always prints blanks, two flake exports with no reader, a
`go/` directory level under a tool that has one implementation, and a `config/`
directory that holds one file. This plan removes each one in its own commit.
Every installed file keeps the same content.

## Why this matters

The top level of a repo is its table of contents. Each leftover here makes a
reader ask what it is for, and the answer is "nothing now". The `drift` recipe
is worse than clutter: it reports a blank version for every tool, which reads
as "not installed".

## Current state

### A. `just drift` reads a profile that Home Manager never fills

`justfile:149-154`:

```make
# Show drift between binaries currently on PATH and the versions pinned
# in the flake. Useful when a CLI prints "newer version available".
drift:
    @for b in amp droid codex pi omp; do \
        printf '%-10s %s\n' "$b" "$(readlink -f ~/.nix-profile/bin/$b 2>/dev/null | sed -E 's|.*-([0-9][^/]*)/bin.*|\1|')"; \
    done
```

`lib/mkSystem.nix:59` sets `useUserPackages = true;`. With that setting Home
Manager installs packages under `/etc/profiles/per-user/<user>/bin`, not under
`~/.nix-profile/bin`. So every `readlink` fails and the recipe prints five
names with no version. No file calls the recipe:
`rg -n 'just drift' --glob '!plans/**' --glob '!references/**' .` printed
nothing on 2026-11-27.

### B. Two flake exports with no reader

`flake.nix:157-165`:

```nix
      legacyPackagesFor = s:
        let
          pkgs = pkgsFor s;
        in
        {
          crush = pkgs.martin.crush;
          # Overlay override of nixpkgs' codex; exposed so update-codex.sh can build it.
          inherit (pkgs) codex martin typescript;
        };
```

- `crush` is an alias. Its only reader is `scripts/update-crush.sh` (whole file):

  ```bash
  #!/usr/bin/env bash
  . "$(dirname "$0")/lib/auto-update.sh"
  cd "$(au_repo_root)"

  crush_version() {
    nix eval --raw .#crush.version 2>/dev/null || nix eval --raw .#crush.name
  }

  before=$(crush_version)
  nix flake update charm-nur 2>&1 | tail -10
  au_build .#crush

  after=$(crush_version)
  if [ "$before" = "$after" ]; then
    echo "crush already at $after"
  else
    au_report_change crush "$before" "$after"
  fi
  ```

  The same package is already reachable as `.#martin.crush`, because `martin`
  is exported on the same line. Other updaters use that form, for example
  `scripts/update-droid.sh:16` (`--attr .#martin.droid`).
- `typescript` has no reader.
  `rg -n '\.#typescript|legacyPackages\.[a-z0-9_-]+\.typescript' --glob '!plans/**' --glob '!references/**' .`
  printed nothing on 2026-11-27.
- `codex` and `martin` both have readers. Keep them.

### C. `tools/agent-trace/go/` is a directory level with nothing beside it

`tools/agent-trace/` holds `SCHEMA.md` and `go/`. `go/` holds `flow.go`,
`go.mod`, `main.go`, `model.go`, `parse.go`, `prompts.go`, `stats.go`, and
`README.md`. A second implementation used to sit beside `go/`. It is gone.

References to the `go/` level:

- `pkgs/agent-trace.nix:9`: `src = ../tools/agent-trace/go;`
- `.gitignore:30-32`:

  ```gitignore
  # Compiled agent-trace binary. The Go sources are checked in. The built
  # binary is host-specific and rebuildable with `go build`.
  /tools/agent-trace/go/agent-trace
  ```

- `tests/default.nix:297`: `echo "Building tools/agent-trace/go..."`
- `tests/README.md:66`, in the checks table: `` `tools/agent-trace/go` compiles and exposes an executable `agent-trace`. ``
- `tools/agent-trace/go/README.md:12`: ``Commands match `../SCHEMA.md`: ...``

### D. `config/` holds one file

`config/omp/README.md` is the only file under `config/`. Its one reader is
`modules/home/agent-instructions.nix:21`:

```nix
    ".config/agent-routing/README.md" = ../../config/omp/README.md;
```

Lines 22-25 of the same file read the other OMP files from
`./agent-instructions/omp/agent/agents/`.

Repo rules that apply:

- A `doc-lock` hook blocks Markdown and comment changes outside docs work.
  Parts C and D move or edit Markdown, and part C edits one comment in
  `.gitignore`. If the hook blocks an edit, stop and report.
- Nix sees only files Git tracks. After creating a file, run
  `git add -N <path>`. `git mv` already stages its result.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | prints one `/nix/store/...drv` path |
| Justfile test | `nix build --no-link '.#checks.aarch64-darwin.unit-justfile'` | exit 0 |
| Agent-trace build | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.smoke-build-agent-trace'` | exit 0 |
| README table | `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` | exit 0 |
| Home checks | `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| Format | `nix fmt -- --check flake.nix pkgs/agent-trace.nix tests/default.nix modules/home/agent-instructions.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `justfile` (delete the `drift` recipe and its two comment lines)
- `flake.nix` (the `legacyPackagesFor` attribute set only)
- `scripts/update-crush.sh`
- `tools/agent-trace/` (move the files in `go/` up one level)
- `pkgs/agent-trace.nix` (line 9)
- `.gitignore` (line 32)
- `tests/default.nix` (the `echo` on line 297)
- `tests/README.md` (line 66)
- `config/omp/README.md` (move)
- `modules/home/agent-instructions.nix` (line 21)

**Out of scope** (do NOT touch):

- The `_drift-hint` recipe at `justfile:102`. It is a different recipe and
  `build` and `switch` call it.
- The `codex` and `martin` exports in `flake.nix`.
- The text of `config/omp/README.md`. Its model table disagrees with other
  docs. Issue #426 tracks that.
- `ARCHITECTURE.md`, if it exists. Plan 031 fixes paths in maintained docs.

## Git workflow

- Branch: `advisor/021-remove-four-root-leftovers`.
- Four commits, one per part:
  1. `chore(just): delete the drift recipe that prints blanks`
  2. `chore(flake): drop the crush alias and the unread typescript export`
  3. `refactor(agent-trace): flatten tools/agent-trace/go`
  4. `refactor(omp): move the agent-routing README beside the OMP files`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baseline

Run the Invariance command and save its output as `BEFORE`.

### Step 2: Delete the `drift` recipe (part A)

In `justfile`, delete lines 149-154: the two comment lines, the `drift:` line,
the three recipe lines, and one of the blank lines around them.

**Verify**: `rg -n '^drift:' justfile` prints nothing.
`rg -n '^_drift-hint:' justfile` prints one line.
The Justfile test command exits 0. Commit (commit 1).

### Step 3: Drop the two exports (part B)

1. In `scripts/update-crush.sh`, replace `.#crush.version` with
   `.#martin.crush.version`, `.#crush.name` with `.#martin.crush.name`, and
   `au_build .#crush` with `au_build .#martin.crush`. Leave
   `au_report_change crush` as it is.
2. In `flake.nix`, delete the line `crush = pkgs.martin.crush;` and change
   `inherit (pkgs) codex martin typescript;` to `inherit (pkgs) codex martin;`.
   Keep the comment line above it.

**Verify**:

- `nix eval --raw '.#martin.crush.name'` prints a name that starts with `crush`.
- `nix eval '.#legacyPackages.aarch64-darwin' --apply builtins.attrNames`
  prints `[ "codex" "martin" ]`.
- `nix eval --raw '.#legacyPackages.aarch64-darwin.codex.drvPath'` prints a
  `.drv` path.
- `rg -n '\.#crush' scripts` prints nothing.

Commit (commit 2).

### Step 4: Flatten `tools/agent-trace/go` (part C)

1. Run `git ls-files tools/agent-trace/go`. It must list exactly the eight
   files named in "Current state". Any other tracked file is a STOP condition.
2. Move each file up with `git mv`, one command per file, for example
   `git mv tools/agent-trace/go/main.go tools/agent-trace/main.go`.
3. If an untracked `tools/agent-trace/go/agent-trace` binary exists, delete
   that one file. Then remove the empty directory with
   `rmdir tools/agent-trace/go`.
4. In `pkgs/agent-trace.nix`, change line 9 to `src = ../tools/agent-trace;`.
5. In `.gitignore`, change line 32 to `/tools/agent-trace/agent-trace`.
6. In `tests/default.nix`, change the echo to
   `echo "Building tools/agent-trace..."`.
7. In `tests/README.md` line 66, change `` `tools/agent-trace/go` `` to
   `` `tools/agent-trace` ``.
8. In `tools/agent-trace/README.md`, change `` `../SCHEMA.md` `` to
   `` `SCHEMA.md` ``.

**Verify**: `test ! -e tools/agent-trace/go` exits 0.
`rg -n 'agent-trace/go' --glob '!plans/**' --glob '!references/**' .` prints nothing.
The Agent-trace build and README table commands exit 0. Commit (commit 3).

### Step 5: Move the routing README (part D)

1. Run `mkdir -p modules/home/agent-instructions/omp/agent-routing`.
2. Run `git mv config/omp/README.md modules/home/agent-instructions/omp/agent-routing/README.md`.
3. Run `rmdir config/omp config`.
4. In `modules/home/agent-instructions.nix`, change line 21 as shown below.
   If that file does not exist, plan 025 has moved it to
   `modules/home/agent-instructions/default.nix`. Edit the same line there,
   and write the path as `./omp/agent-routing/README.md`. The new form is:

   ```nix
       ".config/agent-routing/README.md" = ./agent-instructions/omp/agent-routing/README.md;
   ```

   The file keeps the base name `README.md` on purpose. Nix names the store
   copy after the base name, so a different name would change the build.

**Verify**: `test ! -e config` exits 0.
`rg -n 'config/omp' --glob '!plans/**' --glob '!references/**' .` prints nothing.
The Home checks command exits 0.

### Step 6: Check that nothing installed changed

Run the Invariance command and save its output as `AFTER`.

**Verify**: `AFTER` equals `BEFORE` exactly. The Format command exits 0.
Commit (commit 4).

## Test plan

- No new test. Parts A and B remove code with no reader. Parts C and D are
  moves, and the gate is build invariance.
- `smoke-build-agent-trace` proves the Go tool still builds from the new path.

## Done criteria

- [ ] `rg -n '^drift:' justfile` returns no matches
- [ ] `rg -n '\.#crush' scripts` returns no matches
- [ ] `test ! -e tools/agent-trace/go && test ! -e config` exits 0
- [ ] `nix build --no-link '.#checks.aarch64-darwin.smoke-build-agent-trace' '.#checks.aarch64-darwin.unit-tests-readme' '.#checks.aarch64-darwin.unit-justfile' '.#checks.aarch64-darwin.integration-configurations-eval'` exits 0
- [ ] The Step 6 invariance check passed
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `rg -n 'just drift'` finds a caller outside `plans/`.
- Any file outside `scripts/update-crush.sh` reads `.#crush` or the
  `typescript` export.
- `tools/agent-trace/go` tracks a file not listed in "Current state".
- The Step 6 invariance check fails.
- The `doc-lock` hook blocks a Markdown or comment edit.

## Maintenance notes

- `pkgs.martin.agent-trace` is built by a smoke check and installed nowhere.
  Whether to install it is the maintainer's choice. This plan does not decide it.
- The nightly workflow runs `scripts/update-crush.sh` on a Linux runner.
  `.#martin.crush` resolves there the same way `.#crush` did, through
  `legacyPackages.<system>.martin`.
