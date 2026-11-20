# Plan 010: `tools/agent-trace` has one implementation, and the flake builds it

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- tools/agent-trace pkgs/default.nix tests/default.nix tests/README.md .gitignore`
> If anything under `tools/agent-trace` changed, stop and report. Someone is
> working on one of the implementations.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

`tools/agent-trace` holds the same command-line tool written three times, in
Go, Python, and Rust. Nothing in the flake builds, installs, or tests any of
them. This plan keeps the Go version, packages it, adds a build check, and
deletes the other two. The shared `SCHEMA.md` and the Go sources are unchanged.

## Why this matters

About 3,000 lines sit in the repo with no build and no test. Every change to
the transcript format must be made three times, and nothing checks that the
three agree. The Rust README calls itself a "scaffold". One built and checked
implementation is cheaper to keep and safer to change.

## Decision this plan assumes

The plan keeps **Go**. Reasons: it has no dependencies outside the standard
library, and it is the only one with a compiled binary on disk. If the operator
prefers Python or Rust, stop before Step 1 and report. The steps below are
written for Go only.

## Current state

Tracked files, from `git ls-files tools/agent-trace` (26 files):

```text
tools/agent-trace/SCHEMA.md
tools/agent-trace/go/README.md
tools/agent-trace/go/{flow,main,model,parse,prompts,stats}.go
tools/agent-trace/go/go.mod
tools/agent-trace/python/README.md
tools/agent-trace/python/agent-trace
tools/agent-trace/python/agent_trace/{__init__,__main__,flow,parse,prompts,stats}.py
tools/agent-trace/rust/{Cargo.lock,Cargo.toml,README.md}
tools/agent-trace/rust/src/{flow,main,model,parse,prompts,stats}.rs
```

`tools/agent-trace/go/go.mod` today (whole file):

```text
module agent-trace

go 1.26.4
```

There is no `go.sum`, because there are no dependencies.

`tools/agent-trace/SCHEMA.md:35` heads the shared contract:

```markdown
## CLI contract (all three implementations)
```

`.gitignore:30-33` today:

```text
# Compiled agent-trace binaries. The Go/Rust sources are checked in; the built
# ...
/tools/agent-trace/go/agent-trace
/tools/agent-trace/rust/target/
```

References: `rg -n 'agent-trace|agent_trace'` outside `tools/agent-trace`,
`plans/`, and `references/` finds nothing. No package, module, or test uses it.

The overlay, `pkgs/default.nix:43-46`, where packages are registered:

```nix
  martin = {
    mkAppFromZip = final.callPackage ./lib/mk-app-from-zip.nix { };

    hammerspoon = final.callPackage ./hammerspoon.nix { };
```

Packages are listed inside `martin = { ... };` as
`<name> = final.callPackage ./<name>.nix { };`.

An existing package whose source lives outside `pkgs/`, to copy the path
style from: `pkgs/jj-pr.nix` reads `../modules/home/jj-pr/jj-pr.sh`.

An existing smoke check to copy, `tests/default.nix:473-478`:

```nix
  smoke-build-oh-my-pi = onlyOn "darwin" "smoke-build-oh-my-pi"
    (pkgs.runCommand "smoke-build-oh-my-pi" { } ''
      echo "Building oh-my-pi as a Darwin smoke test..."
      test -x ${pkgs.martin.oh-my-pi}/bin/omp
      touch $out
    '');
```

`tests/README.md` has a table with one row per check. The check
`unit-tests-readme` fails when the table and the registry disagree.

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments and Markdown outside
  docs work. This plan edits one comment in `.gitignore`, two Markdown files,
  and deletes two READMEs. If the hook blocks an edit, stop and report which one.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Build the package | `nix build --no-link --print-build-logs '.#legacyPackages.aarch64-darwin.martin.agent-trace'` | exit 0 |
| Smoke check | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.smoke-build-agent-trace'` | exit 0 |
| README guard | `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` | exit 0 |
| Overlay check | `nix build --no-link '.#checks.aarch64-darwin.unit-overlay'` | exit 0 |
| Format | `nix fmt -- --check pkgs/agent-trace.nix pkgs/default.nix tests/default.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `pkgs/agent-trace.nix` (create)
- `pkgs/default.nix` (add one line)
- `tests/default.nix` (add one check)
- `tests/README.md` (add one table row)
- `tools/agent-trace/python/` (delete the directory)
- `tools/agent-trace/rust/` (delete the directory)
- `tools/agent-trace/SCHEMA.md` (one heading)
- `.gitignore` (lines 30-33)

**Out of scope** (do NOT touch):

- Every file under `tools/agent-trace/go/`. Do not change the Go code.
- `modules/home/packages.nix`. Installing the tool on PATH is a separate choice.
- The untracked binary `tools/agent-trace/go/agent-trace`. It is ignored by git.
  Leave it on disk.

## Git workflow

- Branch: `advisor/010-keep-one-agent-trace-implementation`.
- Two commits:
  1. `build(agent-trace): package the Go implementation and add a build check`
  2. `chore(agent-trace): delete the Python and Rust copies`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Package the Go implementation

Create `pkgs/agent-trace.nix`:

```nix
{ lib
, buildGoModule
}:

buildGoModule {
  pname = "agent-trace";
  version = "0.1.0";

  src = ../tools/agent-trace/go;

  vendorHash = null;

  meta = {
    description = "Streams Claude Code JSONL transcripts into stats, first prompts, and a flow tree";
    license = lib.licenses.mit;
    mainProgram = "agent-trace";
    platforms = lib.platforms.unix;
  };
}
```

In `pkgs/default.nix`, inside `martin = { ... };`, add this line directly above
the line `bun-canary-bin = final.callPackage ./bun-canary-bin.nix { };`:

```nix
    agent-trace = final.callPackage ./agent-trace.nix { };
```

Run `git add -N pkgs/agent-trace.nix`.

**Verify**: `nix build --no-link --print-build-logs '.#legacyPackages.aarch64-darwin.martin.agent-trace'` exits 0.

### Step 2: Add the build check

In `tests/default.nix`, directly after the closing `'');` of the
`smoke-build-oh-my-pi` entry, add a blank line and then:

```nix
  smoke-build-agent-trace = pkgs.runCommand "smoke-build-agent-trace" { } ''
    echo "Building tools/agent-trace/go..."
    test -x ${pkgs.martin.agent-trace}/bin/agent-trace
    touch $out
  '';
```

In `tests/README.md`, add this row to the table under "What each test does",
after the `smoke-build-oh-my-pi` row:

```markdown
| `smoke-build-agent-trace`           | `tools/agent-trace/go` compiles and exposes an executable `agent-trace`. |
```

**Verify**: `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.smoke-build-agent-trace'` exits 0.
`nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` exits 0.

Commit (commit 1).

### Step 3: Delete the other two implementations

Delete the directories `tools/agent-trace/python` and `tools/agent-trace/rust`
with `git rm -r tools/agent-trace/python tools/agent-trace/rust`.

In `tools/agent-trace/SCHEMA.md`, change the heading
`## CLI contract (all three implementations)` to `## CLI contract`.

In `.gitignore`, delete the line `/tools/agent-trace/rust/target/`. In the
comment above it, change `The Go/Rust sources are checked in` to
`The Go sources are checked in`. Change nothing else in that comment.

**Verify**: `git ls-files tools/agent-trace | rg -c .` prints `9`.
`rg -n 'python|rust|Rust|three implementations' tools/agent-trace/SCHEMA.md tools/agent-trace/go/README.md` — review each hit. A hit that points the reader
at a deleted directory is a STOP condition. Report it instead of rewording it.

### Step 4: Run the checks again

**Verify**, all exit 0:

- `nix build --no-link '.#checks.aarch64-darwin.smoke-build-agent-trace'`
- `nix build --no-link '.#checks.aarch64-darwin.unit-overlay'`
- `nix build --no-link '.#checks.aarch64-darwin.unit-doc-links'`
- `nix fmt -- --check pkgs/agent-trace.nix pkgs/default.nix tests/default.nix`

Commit (commit 2).

## Test plan

- One new check, `smoke-build-agent-trace`. It proves the Go code compiles
  against the pinned toolchain. It does not test behaviour.
- Structural pattern: `smoke-build-oh-my-pi` in `tests/default.nix`.

## Done criteria

- [ ] `nix build --no-link '.#checks.aarch64-darwin.smoke-build-agent-trace'` exits 0
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` exits 0
- [ ] `test ! -e tools/agent-trace/python && test ! -e tools/agent-trace/rust/Cargo.toml`
- [ ] `git diff --stat 534fc39..HEAD -- tools/agent-trace/go` is empty
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The operator prefers a different implementation than Go.
- Step 1 fails with `go.mod requires go >= 1.26.4`. The pinned nixpkgs Go is
  older than the module asks for. Do not edit `go.mod`. Report the Go version
  from `nix eval --raw '.#legacyPackages.aarch64-darwin.martin.agent-trace.go.version'`
  or from the build log.
- Step 1 fails with a `vendorHash` mismatch. Then the module gained dependencies.
- Any file outside `tools/agent-trace`, `plans/`, and `references/` mentions
  `agent-trace` or `agent_trace` before you start.
- The `doc-lock` hook blocks a Markdown or comment edit.

## Maintenance notes

- The tool is built but not installed. To put it on PATH, add
  `pkgs.martin.agent-trace` to `modules/home/packages.nix`.
- A behaviour test is the natural next step: a small fixture `.jsonl` file and
  a check that runs `agent-trace stats` on it. `SCHEMA.md` is the contract for
  that fixture.
- The deleted Python and Rust versions stay in git history at `534fc39`.
