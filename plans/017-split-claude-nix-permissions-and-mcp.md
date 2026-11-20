# Plan 017: `claude.nix` sheds its permission lists, MCP registration, and Antigravity workflows

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- modules/home/claude.nix modules/home/antigravity modules/home/default.nix`
> `modules/home/claude.nix` had uncommitted edits when this plan was written,
> and plan 012 edits its `pstack` lines. Line numbers below will have moved.
> Find each block by the names given. If a named binding no longer exists,
> stop and report.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: 012 (edits the same file) and 014 (moves the assertions that read this module). Both are done.
- **Category**: tech-debt
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

`modules/home/claude.nix` is 706 lines and owns eight unrelated jobs. Three of
them use nothing else in the file: the permission rule lists, the MCP
registration script, and the Antigravity workflow mirror. This plan moves each
to its own file. The Home Manager activation package must evaluate to the same
derivation as before.

## Why this matters

`claude.nix` changed in 61 commits in three months, more than any other
module. The Antigravity activation script sits in the Claude module while
`modules/home/antigravity/` exists. A reader looking for a permission rule
scrolls past 160 lines of rules to reach the next job, and a reader of any
other job scrolls past them too.

## Current state

Files:

- `modules/home/claude.nix` — the module. Header: `{ inputs, pkgs, lib, config, ... }:`.
  Line 5: `isDarwin = pkgs.stdenv.hostPlatform.isDarwin;`.
  Line 7: `homeDir = config.home.homeDirectory;`.
- `modules/home/claude/` — helper files beside it: `pstack.nix`,
  `settings-ownership.nix`, `skill-curation.nix`, `hooks/`.
- `modules/home/antigravity/default.nix` — 27 lines, header `{ lib, pkgs, ... }:`,
  sets only `home.file`.
- `modules/home/default.nix` — imports `./claude.nix` and `./antigravity`.

**Block A: permissions.** Lines 127-285 at `534fc39`. It starts:

```nix
  # === permissions: nix-owned, authoritative ===
  # Rewritten every switch; a runtime-added rule not listed here is dropped.
  # Order is deny → ask → allow, first match wins, regardless of specificity.
  claudeAllowRules = [
    "Bash(cliproxyapi -codex-login)"
```

and ends:

```nix
  ] ++ lib.optionals isDarwin [
    "Read(~/Applications/**)"
    "Edit(~/Applications/**)"
  ];

  # The declaration below owns this exact object, including the plugin-skill
  # deny rules. Keeping one value avoids competing writers and rewrite loops.
  claudePermissions = {
    defaultMode = "bypassPermissions";
    allow = claudeAllowRules;
    deny = lib.unique (claudeDenyRules ++ deniedPluginSkills ++ deniedPluginMcpServers);
    ask = claudeAskRules;
  };
```

It defines `claudeAllowRules`, `claudeDenyRules`, `claudeAskRules`, and
`claudePermissions`. Its free variables are `lib`, `isDarwin`,
`deniedPluginSkills`, and `deniedPluginMcpServers`.

**Block B: MCP registration.** Lines 599-659. It starts:

```nix
  # alwaysLoad skips tool-search deferral, so Claude uses them over Bash rg.
  # Registered via `claude mcp` (~/.claude.json holds other CLI state).
  # No env here: the patched defaults live in pkgs/drafts-mcp-server.nix.
  home.activation.claudeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeBin="${pkgs.claude-code}/bin/claude"
    jqBin="${pkgs.jq}/bin/jq"
    target="${homeDir}/.claude.json"
```

and ends with `fi` and `'';`. Its free variables are `lib`, `pkgs`, `homeDir`,
and `isDarwin`.

**Block C: Antigravity workflows.** Lines 661-677:

```nix
  # Antigravity Desktop's `/` menu lists workflows, not skills.
  home.activation.antigravityWorkflows = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wfDir="${homeDir}/.gemini/config/workflows"
    skillDir="${homeDir}/.gemini/config/skills"
    if [ -n "''${DRY_RUN:-}" ]; then
      ...
    fi
  '';
```

Its free variables are `lib` and `homeDir`.

Tests that read these blocks:

- `tests/integration/configurations-eval-test.nix` reads
  `home.activation.claudeMcp.data` with `lib.hasInfix` (two assertions).
- `tests/unit/skill-hygiene-test.nix:22` reads the **text** of
  `modules/home/claude.nix` with `builtins.readFile`. Moving text out of the
  file can break a pattern it looks for.

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Move each comment word for word with its code. Add none. If the hook blocks
  a moved comment, stop and report.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. The `find`
  inside Block C is Nix-rendered code. Move it unchanged.
- Never run `just switch`, `just sync`, or `darwin-rebuild`.

## Commands you will need

Run from the repo root, on the macOS host. `HM` below stands for
`.#darwinConfigurations.f.config.home-manager.users.martinfan`.

| Purpose | Command | Expected on success |
|---|---|---|
| Activation invariance | `nix eval --raw '.#darwinConfigurations.f.config.home-manager.users.martinfan.home.activationPackage.drvPath'` | one `/nix/store/...drv` path |
| Host invariance | `nix eval --raw '.#darwinConfigurations.f.system.drvPath'` | one `/nix/store/...drv` path |
| Hygiene test | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-skill-hygiene'` | exit 0 |
| Settings test | `nix build --no-link '.#checks.aarch64-darwin.unit-claude-settings-ownership'` | exit 0 |
| Host eval | `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| Format | `nix fmt -- --check modules/home/claude.nix modules/home/claude modules/home/antigravity` | exit 0 |
| Lint | `nix develop --command deadnix --fail modules/home/claude.nix modules/home/claude/permissions.nix modules/home/claude/mcp.nix modules/home/antigravity/default.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `modules/home/claude.nix`
- `modules/home/claude/permissions.nix` (create)
- `modules/home/claude/mcp.nix` (create)
- `modules/home/antigravity/default.nix`

**Out of scope** (do NOT touch):

- Any rule string, script line, or comment text. This plan only moves text.
- The skills, pstack, hooks, settings-seed, and prune-activation parts of `claude.nix`.
- `modules/home/default.nix`. The new module is imported from `claude.nix`.
- Every test file.

## Git workflow

- Branch: `advisor/017-split-claude-nix-permissions-and-mcp`.
- Three commits, one per step 2, 3, and 4:
  1. `refactor(claude): move the permission rule lists to claude/permissions.nix`
  2. `refactor(claude): move MCP registration to claude/mcp.nix`
  3. `refactor(antigravity): own the workflow mirror activation`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baselines

Run the Activation invariance and Host invariance commands. Save both paths
as `HM_BEFORE` and `HOST_BEFORE`.

Run `rg -n 'claudeAllowRules|claudeDenyRules|claudeAskRules' modules/home/claude.nix`.
Each name must appear exactly twice: its definition and its use inside
`claudePermissions`. Any other use is a STOP condition.

### Step 2: Move Block A to `claude/permissions.nix`

Create `modules/home/claude/permissions.nix`:

```nix
{ lib, isDarwin, deniedPluginSkills, deniedPluginMcpServers }:

let
  # claudeAllowRules, claudeDenyRules, claudeAskRules and their comments,
  # moved verbatim
in
# the comment above claudePermissions, then its attribute set, moved verbatim
{
  defaultMode = "bypassPermissions";
  allow = claudeAllowRules;
  deny = lib.unique (claudeDenyRules ++ deniedPluginSkills ++ deniedPluginMcpServers);
  ask = claudeAskRules;
}
```

The two `#` lines inside the template above are placeholders for you. Do not
write them into the file.

In `modules/home/claude.nix`, replace all of Block A with:

```nix
  claudePermissions = import ./claude/permissions.nix {
    inherit lib isDarwin deniedPluginSkills deniedPluginMcpServers;
  };
```

Run `git add -N modules/home/claude/permissions.nix`.

**Verify**: the Activation invariance command prints `HM_BEFORE`.
The Hygiene test exits 0. Commit.

### Step 3: Move Block B to `claude/mcp.nix`

Create `modules/home/claude/mcp.nix`:

```nix
{ config, lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  homeDir = config.home.homeDirectory;
in
{
  # the three comment lines and the whole home.activation.claudeMcp binding,
  # moved verbatim
}
```

In `modules/home/claude.nix`:

1. Delete Block B.
2. Change `imports = [ inputs.agent-skills.homeManagerModules.default ];` to
   `imports = [ inputs.agent-skills.homeManagerModules.default ./claude/mcp.nix ];`.

Run `git add -N modules/home/claude/mcp.nix`.

**Verify**: the Activation invariance command prints `HM_BEFORE`. Commit.

### Step 4: Move Block C to the Antigravity module

In `modules/home/antigravity/default.nix`:

1. Change the header to `{ config, lib, pkgs, ... }:`.
2. Add `homeDir = config.home.homeDirectory;` to the `let` block.
3. Add Block C, with its comment, as a second attribute after `home.file = { ... };`.

In `modules/home/claude.nix`, delete Block C.

**Verify**: the Activation invariance command prints `HM_BEFORE`.
The Host invariance command prints `HOST_BEFORE`. Commit.

### Step 5: Lint and run the tests

**Verify**, all exit 0:

- the Format command
- the Lint command. If `deadnix` reports `isDarwin` or `homeDir` unused in
  `claude.nix`, the name has no other user left. Remove that binding and
  re-run the Activation invariance command.
- the Hygiene test, the Settings test, and the Host eval build

## Test plan

- No new test. The gate is derivation invariance of the Home Manager
  activation package after each move.
- The Linux hosts cannot be evaluated on macOS. CI evaluates them. Say so in
  your report.

## Done criteria

- [ ] The Activation invariance command prints `HM_BEFORE` after Step 4
- [ ] The Host invariance command prints `HOST_BEFORE` after Step 4
- [ ] `wc -l modules/home/claude.nix` reports fewer than 480 lines
- [ ] `rg -n 'antigravity|registerMcp|claudeAllowRules' modules/home/claude.nix` prints nothing
- [ ] The three test builds in Step 5 exit 0
- [ ] `git status --short` lists only the four in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `modules/home/claude.nix` has uncommitted changes when you start
  (`git status --short modules/home/claude.nix`). They belong to the operator.
- A rule-list name is used outside `claudePermissions` (Step 1).
- The Hygiene test fails after a move. It reads `claude.nix` as text. Report
  which pattern it missed. Do not edit the test.
- An invariance command prints a different path and a careful diff of the
  moved text does not explain it within two attempts.
- The `doc-lock` hook blocks a moved comment.

## Maintenance notes

- A new permission rule goes in `modules/home/claude/permissions.nix`.
- A new MCP server for Claude goes in `modules/home/claude/mcp.nix`.
- Follow-up, deferred: the three plugin and skill prune activations
  (about 70 lines) can move next. They depend on bindings in `claude.nix`, so
  they need an explicit argument list first.
