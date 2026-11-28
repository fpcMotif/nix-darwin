# Plan 024: Repo-authored tools keep their sources in `tools/`, and `skill-router` becomes a package

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- pkgs/default.nix pkgs/jj-pr.nix pkgs/recall.nix pkgs/doc-lock.nix pkgs/agent-checkout.nix modules/home/skill-router.nix modules/home/jj-pr modules/home/recall modules/home/doc-lock modules/home/workspace-backend tests/default.nix scripts/comment-lint.sh`
> If any of these changed, compare the "Current state" excerpts against the
> live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

The repo writes six command-line tools of its own, and their sources live in
three kinds of place: `tools/`, inside Home Manager module directories, and
inline in a module. Because of that, four package files in `pkgs/` read
scripts out of `modules/home/`, so the package overlay depends on the module
tree. This plan moves every tool script and its test to `tools/<name>/` and
gives `skill-router` a package file like the others. The built tools are
byte-for-byte the same.

## Why this matters

`flake.nix` exports the overlay as `overlays.default` for other flakes. An
overlay that reaches into `modules/home/` for its sources cannot be read or
reused without the module tree. For a contributor, the cost is simpler: there
is no rule that says where a new tool goes, so each new tool picks a place.
After this plan the rule is one line: sources in `tools/<name>/`, package in
`pkgs/<name>.nix`, wiring in `modules/`.

## Current state

### Where each tool's source is today

| Tool | Source and test today | Package file | Where it is wired |
|---|---|---|---|
| `agent-trace` | `tools/agent-trace/go/` | `pkgs/agent-trace.nix` | a smoke check only |
| `skill-router` | `tools/skill-router/` | none (inline in a module) | `modules/home/skill-router.nix` |
| `jj-pr` | `modules/home/jj-pr/jj-pr.sh`, `jj-pr-test.sh` | `pkgs/jj-pr.nix` | `modules/home/jujutsu.nix:3` |
| `recall` | `modules/home/recall/recall.sh`, `recall-test.sh` | `pkgs/recall.nix` | `modules/home/recall/default.nix` |
| `doc-lock` | `modules/home/doc-lock/doc-lock.sh`, `doc-lock-test.sh`, `agent-extension.ts`, `agent-extension-test.ts` | `pkgs/doc-lock.nix`, and `pkgs/default.nix:62` | `modules/home/doc-lock/default.nix` |
| `agent-checkout` | `modules/home/workspace-backend/agent-checkout.sh`, `agent-checkout-test.sh` | `pkgs/agent-checkout.nix` | `modules/home/workspace-backend/default.nix` |

`modules/home/jj-pr/` holds only the two shell files. It has no Nix file.

### The package files that read from `modules/home/`

`pkgs/jj-pr.nix` (whole file):

```nix
{ writeShellApplication
, coreutils
, jq
}:

# jj, git, and gh come from PATH: pushes keep the user's credential helpers,
# and the unit test can put a stub gh in front.
writeShellApplication {
  name = "jj-pr";
  runtimeInputs = [ coreutils jq ];
  text = builtins.readFile ../modules/home/jj-pr/jj-pr.sh;
}
```

The other three have the same shape. Their `text` lines:

- `pkgs/recall.nix:11`: `text = builtins.readFile ../modules/home/recall/recall.sh;`
- `pkgs/doc-lock.nix:13`: `text = builtins.readFile ../modules/home/doc-lock/doc-lock.sh;`
- `pkgs/agent-checkout.nix:14`: `text = builtins.readFile ../modules/home/workspace-backend/agent-checkout.sh;`

`pkgs/default.nix:61-64`:

```nix
    doc-lock = final.callPackage ./doc-lock.nix { };
    doc-lock-extension = final.replaceVars ../modules/home/doc-lock/agent-extension.ts {
      docLock = final.lib.getExe final.martin.doc-lock;
    };
```

### The test registry lines that name the old paths

`tests/default.nix`:

```nix
  unit-recall = shellTest "unit-recall" {
    script = ../modules/home/recall/recall-test.sh;                      # line 146
  unit-agent-checkout = shellTest "unit-agent-checkout" {
    script = ../modules/home/workspace-backend/agent-checkout-test.sh;   # line 151
  unit-doc-lock = shellTest "unit-doc-lock" {
    script = ../modules/home/doc-lock/doc-lock-test.sh;                  # line 156
    patchShebangs scripts tests/unit modules/home/doc-lock               # line 164
  unit-jj-pr = shellTest "unit-jj-pr" {
    script = ../modules/home/jj-pr/jj-pr-test.sh;                        # line 170
    bun ${../modules/home/doc-lock/agent-extension-test.ts} ${pkgs.martin.doc-lock-extension}   # line 176
```

(The `# line N` notes are for this plan only. They are not in the file.)

One more reader, `scripts/comment-lint.sh:5`:

```bash
doc_lock="$root/modules/home/doc-lock/doc-lock.sh"
```

Three test scripts find the tool next to themselves when run by hand, for
example `modules/home/recall/recall-test.sh:3`:

```bash
RECALL=${1:-$(dirname "$0")/recall.sh}
```

So each script must move together with its test.

### `skill-router` has no package file

`modules/home/skill-router.nix` (whole file):

```nix
{ lib, pkgs, ... }:

let
  toolSrc = lib.cleanSource ../../tools/skill-router;
  # bun-canary-bin is aarch64-darwin only, and evaluating its overlay attribute
  # on Linux fails the NixOS toplevels even behind `or`.
  bun = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.martin.bun-canary-bin else pkgs.bun;
  skillRouter = pkgs.writeShellScriptBin "skill-router" ''
    exec ${bun}/bin/bun ${toolSrc}/src/cli.ts "$@"
  '';
in
{
  home.packages = [ skillRouter ];
}
```

Every other repo tool is `pkgs.martin.<name>`. The exemplar for a small
package file is `pkgs/jj-pr.nix` above. Packages are registered by hand in the
`martin = { ... }` set of `pkgs/default.nix`, one line each, for example
`jj-pr = final.callPackage ./jj-pr.nix { };`.

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Moving a comment together with its code is allowed. Step 5 moves the
  two-line `bun-canary-bin` comment into the new package file unchanged. If
  the hook blocks an edit, stop and report.
- Nix sees only files Git tracks. `git mv` stages its result. After creating
  `pkgs/skill-router.nix`, run `git add -N pkgs/skill-router.nix`.
- The working tree may hold untracked files under `tools/skill-router/test/`
  from another session. Leave them alone.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | prints one `.drv` path |
| Tool checks | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-jj-pr' '.#checks.aarch64-darwin.unit-recall' '.#checks.aarch64-darwin.unit-doc-lock' '.#checks.aarch64-darwin.unit-doc-lock-extension' '.#checks.aarch64-darwin.unit-agent-checkout' '.#checks.aarch64-darwin.unit-comment-lint' '.#checks.aarch64-darwin.unit-skill-router'` | exit 0 |
| Overlay check | `nix build --no-link '.#checks.aarch64-darwin.unit-overlay'` | exit 0 |
| Linux eval | `nix eval --raw '.#nixosConfigurations.x230.config.system.build.toplevel.drvPath'` | prints one `.drv` path |
| Format | `nix fmt -- --check pkgs tests/default.nix modules/home/skill-router.nix` | exit 0 |
| Lint | `nix develop --command deadnix --fail pkgs/skill-router.nix modules/home/skill-router.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `modules/home/jj-pr/jj-pr.sh`, `modules/home/jj-pr/jj-pr-test.sh` (move to `tools/jj-pr/`)
- `modules/home/recall/recall.sh`, `modules/home/recall/recall-test.sh` (move to `tools/recall/`)
- `modules/home/doc-lock/doc-lock.sh`, `doc-lock-test.sh`, `agent-extension.ts`, `agent-extension-test.ts` (move to `tools/doc-lock/`)
- `modules/home/workspace-backend/agent-checkout.sh`, `agent-checkout-test.sh` (move to `tools/agent-checkout/`)
- `pkgs/jj-pr.nix`, `pkgs/recall.nix`, `pkgs/doc-lock.nix`, `pkgs/agent-checkout.nix` (the `text` line of each)
- `pkgs/default.nix` (line 62, and one new line for `skill-router`)
- `pkgs/skill-router.nix` (create)
- `modules/home/skill-router.nix`
- `tests/default.nix` (the six lines listed above)
- `scripts/comment-lint.sh` (line 5)

**Out of scope** (do NOT touch):

- The contents of any moved script or test. This plan changes paths only.
- `modules/home/recall/default.nix`, `modules/home/recall/guide.md`,
  `modules/home/doc-lock/default.nix`, `modules/home/doc-lock/guide.md`, and
  everything else under `modules/home/workspace-backend/`. They are module
  wiring and guides, and they stay.
- `modules/home/claude/hooks/`. Those scripts are installed as files, not
  packaged as tools. They stay where they are.
- `tools/agent-trace/`. Plan 021 flattens it.
- `tests/unit/skill-router-test.nix`. It needs the source tree, not the
  wrapper, and it keeps its own path.
- `scripts/lib/auto-update.sh`. Its hand list of names stays as it is.
- `AGENTS.md` and `ARCHITECTURE.md`. Plan 031 documents the new rule.

## Git workflow

- Branch: `advisor/024-repo-tools-keep-their-sources-in-tools`.
- Five commits, one per tool, in this order:
  1. `refactor(jj-pr): move the script and its test to tools/jj-pr`
  2. `refactor(recall): move the script and its test to tools/recall`
  3. `refactor(doc-lock): move the scripts and their tests to tools/doc-lock`
  4. `refactor(agent-checkout): move the script and its test to tools/agent-checkout`
  5. `refactor(skill-router): build the wrapper as pkgs.martin.skill-router`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baseline

Run the Invariance command and save its output as `BEFORE`.
Run the Linux eval command and save its output as `LINUX_BEFORE`.

### Step 2: Move `jj-pr`

1. `mkdir -p tools/jj-pr`
2. `git mv modules/home/jj-pr/jj-pr.sh tools/jj-pr/jj-pr.sh`
3. `git mv modules/home/jj-pr/jj-pr-test.sh tools/jj-pr/jj-pr-test.sh`
4. `rmdir modules/home/jj-pr`
5. `pkgs/jj-pr.nix`: change the `text` line to
   `text = builtins.readFile ../tools/jj-pr/jj-pr.sh;`
6. `tests/default.nix`: change the `unit-jj-pr` script to
   `script = ../tools/jj-pr/jj-pr-test.sh;`

**Verify**: `nix build --no-link '.#checks.aarch64-darwin.unit-jj-pr'` exits 0.
`test ! -e modules/home/jj-pr` exits 0. Commit (commit 1).

### Step 3: Move `recall` and `doc-lock`

`recall`:

1. `mkdir -p tools/recall`, then `git mv` `recall.sh` and `recall-test.sh`
   from `modules/home/recall/` to `tools/recall/`.
2. `pkgs/recall.nix`: `text = builtins.readFile ../tools/recall/recall.sh;`
3. `tests/default.nix`: `script = ../tools/recall/recall-test.sh;`

**Verify**: `nix build --no-link '.#checks.aarch64-darwin.unit-recall'` exits 0.
`ls modules/home/recall` prints `default.nix` and `guide.md` only. Commit (commit 2).

`doc-lock`:

1. `mkdir -p tools/doc-lock`, then `git mv` the four files `doc-lock.sh`,
   `doc-lock-test.sh`, `agent-extension.ts`, and `agent-extension-test.ts`
   from `modules/home/doc-lock/` to `tools/doc-lock/`.
2. `pkgs/doc-lock.nix`: `text = builtins.readFile ../tools/doc-lock/doc-lock.sh;`
3. `pkgs/default.nix` line 62: change the path to
   `../tools/doc-lock/agent-extension.ts`.
4. `tests/default.nix`:
   - `unit-doc-lock`: `script = ../tools/doc-lock/doc-lock-test.sh;`
   - `unit-comment-lint`: `patchShebangs scripts tests/unit tools/doc-lock`
   - `unit-doc-lock-extension`: `bun ${../tools/doc-lock/agent-extension-test.ts} ${pkgs.martin.doc-lock-extension}`
5. `scripts/comment-lint.sh` line 5: `doc_lock="$root/tools/doc-lock/doc-lock.sh"`

**Verify**: `nix build --no-link '.#checks.aarch64-darwin.unit-doc-lock' '.#checks.aarch64-darwin.unit-doc-lock-extension' '.#checks.aarch64-darwin.unit-comment-lint'` exits 0.
`ls modules/home/doc-lock` prints `default.nix` and `guide.md` only. Commit (commit 3).

### Step 4: Move `agent-checkout`

1. `mkdir -p tools/agent-checkout`, then `git mv` `agent-checkout.sh` and
   `agent-checkout-test.sh` from `modules/home/workspace-backend/` to
   `tools/agent-checkout/`.
2. `pkgs/agent-checkout.nix`:
   `text = builtins.readFile ../tools/agent-checkout/agent-checkout.sh;`
3. `tests/default.nix`: `script = ../tools/agent-checkout/agent-checkout-test.sh;`

**Verify**: `nix build --no-link '.#checks.aarch64-darwin.unit-agent-checkout'` exits 0.
`rg -n 'modules/home/(jj-pr|recall|doc-lock|workspace-backend)/[a-z-]+\.(sh|ts)' --glob '!plans/**' --glob '!references/**' .`
prints nothing. Commit (commit 4).

### Step 5: Check the moves changed no build

Run the Invariance command.

**Verify**: the output equals `BEFORE` exactly. If it differs, a moved file's
content or name changed. That is a STOP condition.

### Step 6: Package `skill-router`

1. Create `pkgs/skill-router.nix`:

   ```nix
   { lib
   , stdenv
   , writeShellScriptBin
   , bun
   , martin
   }:

   let
     toolSrc = lib.cleanSource ../tools/skill-router;
     # bun-canary-bin is aarch64-darwin only, and evaluating its overlay attribute
     # on Linux fails the NixOS toplevels even behind `or`.
     runtime = if stdenv.hostPlatform.isDarwin then martin.bun-canary-bin else bun;
   in
   writeShellScriptBin "skill-router" ''
     exec ${runtime}/bin/bun ${toolSrc}/src/cli.ts "$@"
   ''
   ```

2. Run `git add -N pkgs/skill-router.nix`.
3. In `pkgs/default.nix`, inside `martin = { ... }`, add one line after the
   `recall` line:

   ```nix
       skill-router = final.callPackage ./skill-router.nix { };
   ```

4. Replace the whole of `modules/home/skill-router.nix` with:

   ```nix
   { pkgs, ... }:

   {
     home.packages = [ pkgs.martin.skill-router ];
   }
   ```

**Verify**:

- The Invariance command still prints `BEFORE` exactly. The wrapper text and
  its two inputs are unchanged, so the derivation must be the same.
- The Linux eval command prints `LINUX_BEFORE` exactly.
- `nix build --no-link '.#legacyPackages.aarch64-darwin.martin.skill-router'` exits 0.
- The Tool checks, Overlay check, Format, and Lint commands exit 0.

Commit (commit 5).

## Test plan

- No new test. Every moved script already has a registered check, and the
  checks follow the files to their new paths.
- The gate is build invariance, checked twice: after the four moves, and
  after the `skill-router` package.
- `unit-comment-lint` proves `scripts/comment-lint.sh` still finds `doc-lock.sh`.

## Done criteria

- [ ] `rg -n '\.\./modules' pkgs` returns no matches
- [ ] `rg -n 'modules/home/(jj-pr|recall|doc-lock|workspace-backend)/[a-z-]+\.(sh|ts)' --glob '!plans/**' --glob '!references/**' .` returns no matches
- [ ] `test -f tools/jj-pr/jj-pr.sh && test -f tools/recall/recall.sh && test -f tools/doc-lock/doc-lock.sh && test -f tools/doc-lock/agent-extension.ts && test -f tools/agent-checkout/agent-checkout.sh` exits 0
- [ ] `test ! -e modules/home/jj-pr` exits 0
- [ ] The Tool checks command exits 0
- [ ] The Step 5 and Step 6 invariance checks passed
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- A file outside the Scope list reads one of the moved scripts by its old
  path. Check before Step 2 with
  `rg -n 'jj-pr\.sh|recall\.sh|doc-lock\.sh|agent-extension|agent-checkout\.sh' --glob '!plans/**' --glob '!references/**' --glob '!*.md' .`
  and compare the hits with "Current state".
- An invariance check fails.
- The Linux eval output changes in Step 6. The `martin` argument may then be
  forcing `bun-canary-bin` on Linux.
- `unit-overlay` fails because it now requires metadata on every
  `pkgs.martin` attribute. On 2026-11-27 it checked a fixed list of seven
  names (`tests/unit/overlay-test.nix:14-22`) and `skill-router` is not on it.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- The rule after this plan: a tool the repo writes has its source and its
  test in `tools/<name>/`, its package in `pkgs/<name>.nix`, and only Nix
  wiring and guides in `modules/`. Plan 031 writes this into `AGENTS.md`.
- Plan 025 depends on this plan. It assumes `modules/home/jj-pr/` is gone.
- `scripts/lib/auto-update.sh:139` hand-lists `skill-router` among package
  names that no binary cache holds. It still needs that entry, because
  `writeShellScriptBin "skill-router"` has no `pname = "..."` line for its
  grep to find.
- Hook scripts under `modules/home/claude/hooks/` and
  `modules/home/antigravity/` were left in place on purpose. They are
  installed as plain files by their module, so the module directory is their
  natural home.
