# Plan 026: The Claude Desktop MCP scaffold and the npm shims live in files named for them

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5442cca..HEAD -- modules/home/lsp.nix modules/home/cursor.nix modules/home/default.nix modules/home/claude`
> `modules/home/claude/mcp.nix` must be new since `5442cca`: plan 017 creates
> it. For `lsp.nix` and `cursor.nix`, compare the "Current state" excerpts
> against the live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/017-split-claude-nix-permissions-and-mcp.md
- **Category**: tech-debt
- **Planned at**: commit `5442cca`, 2026-11-27

## At a glance

Two pieces of behaviour sit in modules named for something else: `lsp.nix`
edits the Claude Desktop MCP config, and `cursor.nix` installs `npm`, `npx`,
and `pnpm` commands that run Bun. This plan moves each piece to a file whose
name says what it does. Every installed file and activation script stays
byte-for-byte the same.

## Why this matters

A reader who wants to know why `npm` runs Bun on this machine will search for
`npm` or `bun`, and will not open the Cursor editor module. The same holds for
MCP setup hidden in the language-server module. File names are the first
index of a config repo, and these two entries point at the wrong page.

## Current state

### A. The MCP scaffold in `lsp.nix`

`modules/home/lsp.nix` (whole file, 41 lines):

```nix
{ pkgs, lib, config, ... }:

let
  inherit (lib) hm;

  homeDir = config.home.homeDirectory;
  codexLsp = import ../shared/codex-lsp.nix { inherit lib pkgs; };

  # Disable the typescript-lsp plugin so tsrs stays the sole TypeScript server.
  # Claude Code rejects fileTypes, rootMarkers, restartOnCrash, and maxRestarts.
  claudeLspJson = pkgs.writeText "claude-lsp.json" (builtins.toJSON codexLsp.adapters.claude);

in
{
  home.packages = codexLsp.packages;

  # Project-level .lsp.json at a repo root still overrides this file.
  home.file.".claude/lsp.json".source = claudeLspJson;

  # Seed only the top-level mcpServers key; bridges stay per-project in
  # templates/lsp-overrides/mcp-bridge.json.
  home.activation.claudeDesktopMcpScaffold =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      hm.dag.entryAfter [ "writeBoundary" ] ''
        target="${homeDir}/Library/Application Support/Claude/claude_desktop_config.json"

        if [ ! -f "$target" ]; then
          :
        elif ${pkgs.jq}/bin/jq -e '.mcpServers' "$target" >/dev/null 2>&1; then
          :
        elif [ -n "''${DRY_RUN:-}" ]; then
          echo "claude-desktop: would scaffold empty mcpServers in $target" >&2
        else
          tmp=$(${pkgs.coreutils}/bin/mktemp)
          ${pkgs.jq}/bin/jq '. + { mcpServers: (.mcpServers // {}) }' \
            "$target" > "$tmp" && ${pkgs.coreutils}/bin/mv "$tmp" "$target"
          echo "claude-desktop: scaffolded empty mcpServers in $target" >&2
        fi
      ''
    );
}
```

Lines 20-40 are the scaffold. The rest is language-server setup.

A test reads the activation entry by name,
`tests/integration/configurations-eval/home.nix:299`:

```nix
            let desktop = homeActivation.claudeDesktopMcpScaffold.data;
```

So the attribute name `claudeDesktopMcpScaffold` must not change.

Plan 017 creates `modules/home/claude/mcp.nix` as a Home Manager module that
`modules/home/claude.nix` imports, and moves the Claude Code MCP registration
there. That file is the destination for the scaffold. It did not exist at
`5442cca`.

### B. The npm shims in `cursor.nix`

`modules/home/cursor.nix:15-41`:

```nix
in
{
  home.file = {
    ".local/bin/npm" = {
      text = ''
        #! /bin/sh
        exec bun "$@"
      '';
      executable = true;
    };

    ".local/bin/npx" = {
      text = ''
        #! /bin/sh
        exec bunx "$@"
      '';
      executable = true;
    };

    ".local/bin/pnpm" = {
      text = ''
        #! /bin/sh
        exec bun "$@"
      '';
      executable = true;
    };
  };

  # Gate on Darwin so Linux hosts do not grow a ~/Library tree.
  home.activation.cursorSettings = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.hm.dag.entryAfter [ "writeBoundary" ] ''
```

The `home.file` block has nothing to do with the Cursor editor. The rest of
the file (the `cursorSettingsFile` binding above it and the
`cursorSettings` activation below it) is Cursor configuration.

Single-file modules in `modules/home` are flat files listed in the `imports`
of `modules/home/default.nix`, for example `./ssh.nix` and `./cursor.nix`.
Exemplar of a small module: `modules/home/skill-router.nix`.

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Moving a comment together with its code is allowed. The two-line comment
  above the scaffold moves with it, unchanged. Add no new comment. If the
  hook blocks an edit, stop and report.
- Nix sees only files Git tracks. After creating `modules/home/node-shims.nix`,
  run `git add -N modules/home/node-shims.nix`.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Run every
  command from the repo root.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| Invariance | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | prints one `.drv` path |
| Linux invariance | `nix eval --raw '.#nixosConfigurations.x230.config.system.build.toplevel.drvPath'` | prints one `.drv` path |
| Host checks | `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| Format | `nix fmt -- --check modules/home/lsp.nix modules/home/cursor.nix modules/home/node-shims.nix modules/home/claude/mcp.nix modules/home/default.nix` | exit 0 |
| Lint | `nix develop --command deadnix --fail modules/home/lsp.nix modules/home/cursor.nix modules/home/node-shims.nix modules/home/claude/mcp.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `modules/home/lsp.nix` (remove lines 20-40, and any binding the removal leaves unused)
- `modules/home/claude/mcp.nix` (add the scaffold)
- `modules/home/cursor.nix` (remove the `home.file` block)
- `modules/home/node-shims.nix` (create)
- `modules/home/default.nix` (one new import line)

**Out of scope** (do NOT touch):

- The text of the scaffold script or of the three shims. Not one character.
- `tests/integration/configurations-eval/home.nix`. The attribute name it
  reads does not change.
- Gating the shims on Darwin. See "Maintenance notes".
- `templates/lsp-overrides/`.

## Git workflow

- Branch: `advisor/026-mcp-scaffold-and-npm-shims-live-under-their-own-names`.
- Two commits:
  1. `refactor(claude): move the Claude Desktop MCP scaffold to claude/mcp.nix`
  2. `refactor(home): move the npm, npx, and pnpm shims to node-shims.nix`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Check the precondition and record the baselines

Run `test -f modules/home/claude/mcp.nix`. It must exit 0. If the file is
missing, plan 017 has not landed. That is a STOP condition.

Read `modules/home/claude/mcp.nix`. Note which of `pkgs`, `lib`, and `config`
its first line takes as module arguments.

Run the Invariance and Linux invariance commands. Save the outputs as
`BEFORE` and `LINUX_BEFORE`.

### Step 2: Move the scaffold

1. Cut lines 20-40 of `modules/home/lsp.nix`: the two-line comment and the
   whole `home.activation.claudeDesktopMcpScaffold = ... ;` definition.
2. Paste them into the attribute set that `modules/home/claude/mcp.nix`
   returns, at the end.
3. Make the pasted code resolve its three names in the new file:
   - `hm.dag.entryAfter`: write it as `lib.hm.dag.entryAfter`.
   - `homeDir`: if `mcp.nix` has no `homeDir` binding, write
     `${config.home.homeDirectory}` in its place.
   - If the module's first line lacks `pkgs`, `lib`, or `config`, add the
     missing ones to its argument list.
4. In `modules/home/lsp.nix`, delete the bindings `inherit (lib) hm;` and
   `homeDir = config.home.homeDirectory;` if nothing else in the file uses
   them. Remove `config` from the first line if it is then unused.

**Verify**: `rg -n 'claudeDesktopMcpScaffold' modules/home` prints exactly one
line, in `modules/home/claude/mcp.nix`.
The Invariance command prints `BEFORE` exactly.
The Host checks command exits 0. Commit (commit 1).

### Step 3: Move the shims

1. Create `modules/home/node-shims.nix` holding the `home.file` block cut
   from `modules/home/cursor.nix`, unchanged:

   ```nix
   {
     home.file = {
       ".local/bin/npm" = {
         text = ''
           #! /bin/sh
           exec bun "$@"
         '';
         executable = true;
       };

       ".local/bin/npx" = {
         text = ''
           #! /bin/sh
           exec bunx "$@"
         '';
         executable = true;
       };

       ".local/bin/pnpm" = {
         text = ''
           #! /bin/sh
           exec bun "$@"
         '';
         executable = true;
       };
     };
   }
   ```

2. Run `git add -N modules/home/node-shims.nix`.
3. Delete that `home.file = { ... };` block and the blank line after it from
   `modules/home/cursor.nix`. The module body then starts with the comment
   `# Gate on Darwin so Linux hosts do not grow a ~/Library tree.`
4. In `modules/home/default.nix`, add `./node-shims.nix` to `imports`, on the
   line after `./packages.nix`.

**Verify**: `rg -n 'local/bin/(npm|npx|pnpm)' modules/home` prints three
lines, all in `modules/home/node-shims.nix`.
The Invariance command prints `BEFORE` exactly.
The Linux invariance command prints `LINUX_BEFORE` exactly.
The Format and Lint commands exit 0. Commit (commit 2).

## Test plan

- No new test. Both parts are moves, and the gate is build invariance on the
  Darwin home and the `x230` system.
- `integration-configurations-eval` still reads `claudeDesktopMcpScaffold` by
  name, which proves the activation entry survived the move.

## Done criteria

- [ ] `rg -n 'mcpServers|claudeDesktopMcpScaffold' modules/home/lsp.nix` returns no matches
- [ ] `rg -n 'local/bin' modules/home/cursor.nix` returns no matches
- [ ] `test -f modules/home/node-shims.nix` exits 0
- [ ] `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'` exits 0
- [ ] The invariance checks in Steps 2 and 3 passed
- [ ] `git status --short` lists only in-scope paths (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `modules/home/claude/mcp.nix` does not exist.
- `modules/home/claude/mcp.nix` is not a Home Manager module. A module is a
  function of `{ ... }` arguments, or an attribute set, that sets options
  such as `home.activation`. If it is a plain function called with
  `import ./claude/mcp.nix { ... }`, it cannot hold an activation entry.
- An invariance check fails.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- Observation left for the maintainer: the shims run `bun`, and
  `modules/home/packages.nix:34-35,71-72` installs Bun only on Darwin. On the
  two Linux scaffold hosts, `npm` therefore runs a missing command. Gating
  the shims on Darwin would fix it, and it changes what the Linux homes
  install, so it is not part of this move.
- No maintained doc lists the Home Manager modules one by one, so no doc
  needs a `node-shims.nix` entry.
