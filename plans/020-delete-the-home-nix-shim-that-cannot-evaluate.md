# Plan 020: Delete the `home.nix` shim that cannot evaluate

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- home.nix ARCHITECTURE.md`
> If either file changed, compare the "Current state" excerpts against the
> live files. On a mismatch, treat it as a STOP condition. One change is
> expected: `ARCHITECTURE.md` may be deleted. A docs rewrite that removes it
> was in progress when this plan was written. If `test -e ARCHITECTURE.md`
> fails, skip Step 4 and every `ARCHITECTURE.md` check, and expect Step 1 to
> print nothing.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

`home.nix` at the repo root is documented as a fallback for applying Home
Manager without the flake, but it fails to evaluate because the modules it
imports need `inputs` and the repo overlay, and the shim supplies neither.
This plan deletes the file and the documentation subsection that describes it.
The flake outputs and every installed file stay unchanged.

## Why this matters

`ARCHITECTURE.md` tells a reader to use `home.nix` on a fresh checkout. That is
the one moment the reader has no working system to fall back on, and the file
fails there. A broken recovery path costs time before the reader learns to
ignore it. Nothing in the repo references the file.

## Current state

`home.nix` (whole file, 8 lines):

```nix
# Compatibility shim. The active Home Manager config lives in modules/home.
{ pkgs, ... }:
{
  _module.args.currentSystemUser = "martinfan";
  _module.args.currentSystemUserHome =
    if pkgs.stdenv.hostPlatform.isDarwin then "/Users/martinfan" else "/home/martinfan";
  imports = [ ./modules/home ];
}
```

Why it fails:

- `modules/home/claude.nix:1` takes `inputs` as a module argument, and
  `modules/home/claude.nix:478` uses it inside `imports`:

  ```nix
  imports = [ inputs.agent-skills.homeManagerModules.default ];
  ```

  A value used in `imports` must arrive through `specialArgs`. The shim sets
  only `_module.args`, and it does not set `inputs` at all.
- `modules/home/packages.nix:23` uses `martin.fff-mcp`. `pkgs.martin` exists
  only when the repo overlay is applied, which happens in `lib/mkSystem.nix`.

Measured on 2026-11-27 at `5442cca`. This command evaluated the shim through
Home Manager's own entry point:

```bash
nix eval --impure --raw --expr 'let f = builtins.getFlake (toString ./.); in (f.inputs.home-manager.lib.homeManagerConfiguration { pkgs = f.inputs.nixpkgs.legacyPackages.aarch64-darwin; modules = [ ./home.nix ]; }).activationPackage.drvPath'
```

It failed with:

```text
error: infinite recursion encountered
       … noting that argument `inputs` is not externally provided, so querying `_module.args` instead, requiring `config`
```

The documentation that describes the shim, in `ARCHITECTURE.md`:

- Lines 55-56, the last two lines of the "Repository layout" tree:

  ```text
  ├── .envrc                    # direnv → repo devShell (devShells.<system>.default)
  └── home.nix                  # off-flake Home Manager shim → imports ./modules/home
  ```

- Lines 61-63, a subsection that starts with the heading
  `### Off-flake fallback` and holds one paragraph that begins
  "`home.nix` is a thin compatibility shim".

Why the plan deletes instead of repairing: a working off-flake entry would be a
`homeConfigurations` flake output. `ARCHITECTURE.md:480` says "Do not add that
output until these are settled" and lists five open questions about the
future Linux profile. That decision stands.

Repo rules that apply:

- A `doc-lock` hook blocks Markdown changes outside docs work. This plan edits
  `ARCHITECTURE.md`. If the hook blocks the edit, stop and report. The
  operator then opens docs work for the session.
- Maintained documents describe the current state. Remove the text. Do not
  add a "removed" note.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | prints one `/nix/store/...drv` path |
| References | `rg -n 'home\.nix' --glob '!plans/**' --glob '!references/**' . \| rg -v 'configurations-eval'` | see each step |
| Doc links | `nix build --no-link '.#checks.aarch64-darwin.unit-doc-links'` | exit 0 |

In the table, `\|` stands for a plain pipe. Type `|` when you run the command.

## Scope

**In scope** (the only files you may modify):

- `home.nix` (delete)
- `ARCHITECTURE.md` (the last two lines of the layout tree, and the "Off-flake fallback" subsection)

**Out of scope** (do NOT touch):

- `tests/integration/configurations-eval/home.nix`. It is a test part file
  with the same base name. It is unrelated.
- `flake.nix`. Do not add a `homeConfigurations` output.
- Any other section of `ARCHITECTURE.md`.

## Git workflow

- Branch: `advisor/020-delete-the-home-nix-shim-that-cannot-evaluate`.
- One commit: `chore: delete the home.nix shim that cannot evaluate`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Confirm nothing uses the file

Run the References command.

**Verify**: it prints exactly two lines, both in `ARCHITECTURE.md` (lines 56
and 63). If `ARCHITECTURE.md` does not exist, it prints nothing. Any other
line is a STOP condition.

### Step 2: Record the baseline

Run the Invariance command and save its output as `BEFORE`.

### Step 3: Delete the shim

Run `git rm home.nix`.

**Verify**: `test ! -e home.nix` exits 0.

### Step 4: Remove the documentation

Skip this step if `ARCHITECTURE.md` does not exist. Otherwise, in
`ARCHITECTURE.md`:

1. Delete the `└── home.nix ...` line from the layout tree.
2. On the `.envrc` line above it, change the leading `├──` to `└──`, so the
   tree still ends correctly.
3. Delete the heading `### Off-flake fallback` and the paragraph under it.
   Leave one blank line between the paragraph before it and the heading
   `## Composition model`.

**Verify**: the References command prints nothing.
`rg -n 'Off-flake' ARCHITECTURE.md` prints nothing.

### Step 5: Check that nothing installed changed

Run the Invariance command and save its output as `AFTER`.

**Verify**: `AFTER` equals `BEFORE` exactly. Then run the Doc links command
and confirm exit 0.

Commit.

## Test plan

No new test. The gate is build invariance: the Home Manager activation package
has the same derivation path before and after.

## Done criteria

- [ ] `test ! -e home.nix` exits 0
- [ ] The References command prints nothing
- [ ] The Step 5 invariance check passed
- [ ] `nix build --no-link '.#checks.aarch64-darwin.unit-doc-links'` exits 0
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Step 1 finds a reference outside `ARCHITECTURE.md`.
- `home.nix` no longer matches the excerpt above. Someone may have repaired it.
- The Step 5 invariance check fails.
- The `doc-lock` hook blocks the `ARCHITECTURE.md` edit.

## Maintenance notes

- If the Linux Home Manager profile is ever built, it must be a
  `homeConfigurations` flake output that passes `inputs` through
  `extraSpecialArgs` and applies `lib/overlays.nix`. A root shim can do neither.
- Plan 031 adds a check for paths named in maintained docs. Land this plan
  first, so no doc names `home.nix` when that check starts.
