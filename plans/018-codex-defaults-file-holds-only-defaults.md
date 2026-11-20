# Plan 018: The Codex defaults file holds defaults, not one machine's runtime state

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- modules/home/agent-instructions/codex/config.toml modules/darwin/codex.nix`
> If either file changed, re-derive every line number below with
> `rg -n '^\[' modules/home/agent-instructions/codex/config.toml`.
> If plan 014 has landed, the assertion named in Step 4 lives in
> `tests/integration/configurations-eval/darwin.nix`. Edit it there.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none. Plan 014 has landed, so apply Step 4 to `tests/integration/configurations-eval/darwin.nix`.
- **Category**: tech-debt
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

`config.toml` is installed as the machine-wide Codex defaults, but about 230
of its 510 lines are state that the Codex app wrote on one machine: trusted
project paths, hook approval records, and absolute paths under one home
directory. This plan deletes the state tables, replaces the home path with a
placeholder that Nix fills in, and adds assertions so the state cannot return.
Model routing, plugins, features, and MCP server choices are unchanged.

## Why this matters

The file was copied from `~/.codex/config.toml` and now ships as Nix-owned
defaults. Each project table and hook record goes stale the moment the app
writes a newer one to the user file. The hard-coded home path breaks the file
for any other user name, while every other module reads the user from
`currentSystemUser`. One table registers an MCP server, `codedbpro`, that
`modules/home/cleanup.nix:46-50` removes from another config on every switch.

## Behaviour change to accept

Codex stores project trust and hook approval in the user's writable
`~/.codex/config.toml`. Entries already there keep working. A project or hook
that was trusted **only** through the Nix defaults file asks for trust once
more. If the operator does not accept that, stop before Step 1.

## Current state

Files:

- `modules/home/agent-instructions/codex/config.toml` — the defaults source, about 510 lines.
- `modules/darwin/codex.nix` — renders it to `/etc/codex/config.toml`.
- `tests/integration/configurations-eval-test.nix:601-616` — the assertion `darwin-codex-layered-config`.

`modules/darwin/codex.nix:17-24` today:

```nix
  codexDefaults = lib.replaceStrings
    [ "@PI_PLAN_MODEL@" "@PI_SLOW_MODEL@" "@PI_SMOL_MODEL@" ]
    [
      codexEnvironment.PI_PLAN_MODEL
      codexEnvironment.PI_SLOW_MODEL
      codexEnvironment.PI_SMOL_MODEL
    ]
    (builtins.readFile ../home/agent-instructions/codex/config.toml);
```

The same file defines `home = config.home-manager.users.${currentSystemUser};`
and already uses `home.home.homeDirectory`.

Table layout of `config.toml` at `534fc39` (from `rg -n '^\['`):

| Lines | Tables | Action |
|---|---|---|
| 1-149 | top-level keys, `[agents]`, `[features]`, `[notice]`, `[plugins.*]` | keep |
| 152-313 | 54 tables named `[projects."/Users/martinfan/..."]` | delete |
| 314-339 | `[shell_environment_policy]`, `[tui]` | keep |
| 340-391 | `[hooks.state]` and 13 `[hooks.state."..."]` tables | delete |
| 392-477 | `[mcp_servers.*]`, `[apps.*]`, `[desktop.*]`, `[marketplaces.*]`, `[features.multi_agent_v2]` | keep |
| 478-499 | 7 more `[hooks.state."..."]` tables | delete |
| 500-505 | `[mcp_servers.codedbpro]` | delete |
| 506-end | `[mcp_servers.codedb]` | keep |

Each `[hooks.state."..."]` table holds an `enabled` flag and a `trusted_hash`
value. **Do not copy any hash value into a commit message, report, or file.**

Absolute home paths that remain after the deletions (line numbers at `534fc39`):

```text
9    notify = ["/Users/martinfan/.codex/computer-use/..."]
393  command = "/Users/martinfan/.local/bin/cua-driver"
400  args = ["/Users/martinfan/devv/stagehand/..."]
420  NODE_REPL_TRUSTED_CODE_PATHS = "/Users/martinfan/.codex:/Applications/..."
421  CODEX_HOME = "/Users/martinfan/.codex"
429  NODE_REPL_TRUSTED_SERVICES = '{"browser":"/Users/martinfan/.codex/plugins/cache/..."}'
430  SKY_CUA_SERVICE_PATH = "/Users/martinfan/.codex/computer-use/..."
463  "/Users/martinfan/nix-config" = "zed"
467  source = "/Users/martinfan/.codex/.tmp/bundled-marketplaces/openai-bundled"
471  source = "/Users/martinfan/.cache/codex-runtimes/..."
507  command = "/Users/martinfan/bin/codedb"
```

The existing assertion, `configurations-eval-test.nix:601-616`:

```nix
    (helpers.assertTest "darwin-codex-layered-config"
      (
        let
          codexDefaults = darwinConfig.environment.etc."codex/config.toml".text;
        in
        builtins.hasAttr "codex/config.toml" darwinConfig.environment.etc
          && lib.hasInfix "[lsp.servers.tsrs]" codexDefaults
          ...
          && !(lib.hasInfix "model_reasoning_effort =" codexDefaults)
      )
      "Darwin should keep Codex machine defaults in /etc without locking the user model choice")
```

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments outside docs work.
  Add no comments, in Nix or in TOML. A TOML comment may leave only with the
  table it describes.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`. Edit with
  your edit tool.
- Never run `just switch`, `just sync`, or `darwin-rebuild`.

## Commands you will need

Run from the repo root, on the macOS host. `ETC` below stands for
`.#darwinConfigurations.f.config.environment.etc."codex/config.toml".text`.

| Purpose | Command | Expected on success |
|---|---|---|
| TOML parses | `nix eval '.#darwinConfigurations.f.config.environment.etc."codex/config.toml".text' --apply 't: builtins.attrNames (builtins.fromTOML t)'` | a list of top-level keys |
| Project tables gone | `nix eval '.#darwinConfigurations.f.config.environment.etc."codex/config.toml".text' --apply 't: (builtins.fromTOML t) ? projects'` | `false` |
| Host eval | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| Format | `nix fmt -- --check modules/darwin/codex.nix tests/integration` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `modules/home/agent-instructions/codex/config.toml`
- `modules/darwin/codex.nix`
- `tests/integration/configurations-eval-test.nix` (or `tests/integration/configurations-eval/darwin.nix` after plan 014)

**Out of scope** (do NOT touch):

- `~/.codex/config.toml` and `/etc/codex/config.toml` on disk. Never read or edit them.
- Any key under `[features]`, `[plugins.*]`, `[agents]`, `[tui]`, or model settings.
- The versioned path in `BROWSER_USE_CODEX_APP_VERSION` and the plugin cache
  version inside `NODE_REPL_TRUSTED_SERVICES`. Keep both strings except for
  the home prefix. They are a known follow-up.
- `modules/shared/codex-lsp.nix` and `modules/home/cleanup.nix`.

## Git workflow

- Branch: `advisor/018-codex-defaults-file-holds-only-defaults`.
- Two commits:
  1. `test(codex): assert the defaults file carries no project or hook state`
  2. `fix(codex): drop machine state from the defaults and take the home path from Nix`
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Record the baseline key list

Run the "TOML parses" command. Save the printed list as `KEYS_BEFORE`.

### Step 2: Add the failing assertions

Inside the `darwin-codex-layered-config` assertion, add these four lines
directly after the line `&& !(lib.hasInfix "model_reasoning_effort =" codexDefaults)`:

```nix
          && !(lib.hasInfix "[projects." codexDefaults)
          && !(lib.hasInfix "[hooks.state" codexDefaults)
          && !(lib.hasInfix "@HOME@" codexDefaults)
          && !(lib.hasInfix "/Users/" (builtins.readFile ../../modules/home/agent-instructions/codex/config.toml))
```

After plan 014 the file sits one directory deeper. Then the path starts with
`../../../modules`.

**Verify**: the Host eval build **fails**, and the log names
`darwin-codex-layered-config`. Commit (commit 1).

### Step 3: Delete the state tables

In `config.toml`, delete:

1. Every `[projects."..."]` table with its keys, from the first one through
   the last one before `[shell_environment_policy]`.
2. `[hooks.state]` and every `[hooks.state."..."]` table with its keys, in
   both places.
3. The `[mcp_servers.codedbpro]` table with its keys.

Leave exactly one blank line between the tables that remain.

**Verify**: `rg -c '^\[projects\.|^\[hooks\.state|codedbpro' modules/home/agent-instructions/codex/config.toml` prints nothing.

### Step 4: Replace the home path with a placeholder

In `config.toml`, replace every remaining `/Users/martinfan` with `@HOME@`.

In `modules/darwin/codex.nix`, extend the substitution:

```nix
  codexDefaults = lib.replaceStrings
    [ "@PI_PLAN_MODEL@" "@PI_SLOW_MODEL@" "@PI_SMOL_MODEL@" "@HOME@" ]
    [
      codexEnvironment.PI_PLAN_MODEL
      codexEnvironment.PI_SLOW_MODEL
      codexEnvironment.PI_SMOL_MODEL
      home.home.homeDirectory
    ]
    (builtins.readFile ../home/agent-instructions/codex/config.toml);
```

**Verify**:

- `rg -n '/Users/' modules/home/agent-instructions/codex/config.toml` prints nothing.
- `rg -c '@HOME@' modules/home/agent-instructions/codex/config.toml` prints `11`.
- The "TOML parses" command prints `KEYS_BEFORE` without `projects`. The key
  `hooks` is also gone if `[hooks.state]` was its only table.
- The "Project tables gone" command prints `false`.
- The Host eval build exits 0.

### Step 5: Lint

**Verify**: `nix fmt -- --check modules/darwin/codex.nix tests/integration` exits 0.
Commit (commit 2).

## Test plan

- Four new conditions in `darwin-codex-layered-config`. They fail before
  Step 3 and pass after Step 4.
- `builtins.fromTOML` on the rendered text proves the file still parses and
  that only `projects` and possibly `hooks` left the top level.

## Done criteria

- [ ] The Host eval build exits 0
- [ ] `rg -c '^\[' modules/home/agent-instructions/codex/config.toml` is at least 75 lower than before Step 3
- [ ] `rg -n '/Users/|codedbpro' modules/home/agent-instructions/codex/config.toml` prints nothing
- [ ] No `trusted_hash` value appears in your commits or report
- [ ] `git status --short` lists only in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The operator does not accept the one-time trust prompts.
- A deleted table holds a key other than `trust_level`, `enabled`, or
  `trusted_hash`. Report the key name, not its value.
- `builtins.fromTOML` fails after a deletion. A table header was cut in half.
- The top-level key list loses anything other than `projects` and `hooks`.
- The `doc-lock` hook blocks an edit.

## Maintenance notes

- When the Codex app writes new state, it writes to `~/.codex/config.toml`.
  Never copy that file over the defaults again. Copy single settings.
- Follow-up, deferred: the two versioned app paths still go stale when the
  Codex app updates. The fix is to drop them from the defaults and let the app
  own them, after checking the app rewrites them itself.
- A reviewer should open Codex once after the next switch and confirm it
  starts, lists its MCP servers, and asks for project trust at most once.
