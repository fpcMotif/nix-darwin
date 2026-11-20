# Plan 009: `cleanupLegacyDotfiles` keeps the links Home Manager already owns

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- modules/home/cleanup.nix tests/default.nix tests/README.md`
> If `modules/home/cleanup.nix` changed, compare the "Current state" excerpts
> against the live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `534fc39`, 2026-11-17

## At a glance

An activation script deletes "legacy" files so Home Manager can link its own
versions. The list was never trimmed, so it now deletes links that Home Manager
itself placed, on every switch. This plan makes the delete helper skip any
symlink that resolves into `/nix/store`, and adds the script's first behaviour
test. Hand-placed files and stale non-store links are still removed.

## Why this matters

The script runs before Home Manager's `checkLinkTargets` step. It removes
`~/.local/bin/claude`, `~/.local/bin/droid`, the guard hooks, and the
`npm`/`npx`/`pnpm` shims. Home Manager re-links them a moment later. If the
link check fails in between, for example on an unrelated file collision, the
switch aborts and those commands and hooks are gone until the next good
switch. A missing guard hook fails open: the agent runs with no shell guard.

## Current state

Files:

- `modules/home/cleanup.nix` — defines `home.activation.cleanupLegacyDotfiles`.
- `modules/home/claude.nix:505-518`, `modules/home/droid.nix:5`,
  `modules/home/cursor.nix:17-39` — the `home.file` entries that own the same paths.
- `tests/default.nix` — the check registry.
- `tests/README.md` — table with one row per check. The check
  `unit-tests-readme` fails when the table and the registry disagree.

`modules/home/cleanup.nix:1-12` today:

```nix
{ config, lib, pkgs, ... }:

let
  skillTargetDirs = lib.escapeShellArgs (lib.attrValues config.martin.agentSurface.skillTargetDirs);
in
{
  home.activation.cleanupLegacyDotfiles = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    remove_legacy_path() {
      if [ -e "$1" ] || [ -L "$1" ]; then
        rm -rf -- "$1"
      fi
    }
```

Entries that collide with Home Manager, same file:

```nix
    remove_legacy_path "$HOME/.local/bin/claude"        # line 32
    remove_legacy_path "$HOME/.local/bin/droid"         # line 33
    remove_legacy_path "$HOME/.claude/CLAUDE.md"        # line 37
    remove_legacy_path "$HOME/.claude/statusline-command.sh"   # line 62
    remove_legacy_path "$HOME/.claude/hooks/search-guard.sh"   # line 65
    remove_legacy_path "$HOME/.config/ripgrep/agent-config"    # line 69
    remove_legacy_path "$HOME/.local/bin/npm"           # line 76
```

(The `# line N` notes are for you. They are not in the file.)

Two loops in the same script must keep deleting store links. They prune
per-project skills from the global picker dirs, `modules/home/cleanup.nix:51-60`:

```nix
    # aily-md is a per-project skill (Feishu aily docs); it leaves the global pickers.
    for d in ${skillTargetDirs}; do
      if [ -L "$HOME/$d/aily-md" ]; then remove_legacy_path "$HOME/$d/aily-md"; fi
    done
    # hyperframes and related video skills are per-project; prune them from global pickers.
    for d in ${skillTargetDirs} .gemini/skills; do
      for skill in hyperframes hyperframes-cli ... hyperframes-keyframes; do
        if [ -L "$HOME/$d/$skill" ] || [ -d "$HOME/$d/$skill" ]; then remove_legacy_path "$HOME/$d/$skill"; fi
      done
    done
```

`skillTargetDirs` includes `.claude/skills` (`modules/home/agent-surface.nix:17`).

The repo's existing pattern for "this link is ours",
`modules/home/agent-instructions.nix:85-88`:

```nix
        if [ -L "$target" ]; then
          resolved="$(${pkgs.coreutils}/bin/readlink -f "$target" || true)"
          case "$resolved" in /nix/store/*) continue ;; esac
        fi
```

The script's last function reads `$newGenPath`. When that variable is unset it
returns early, so the whole script can run outside a real activation.

Test helpers in `tests/default.nix:13-25`:

```nix
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
```

Repo rules that apply:

- Nix flakes read only git-tracked files. After creating a file, run `git add -N <path>`.
- A `doc-lock` hook blocks new or changed code comments outside docs work. Add
  no comments, and keep every existing comment as written. The `tests/README.md`
  row is Markdown. If the hook blocks it, stop and report the exact row text.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.
- Never run `just switch`, `just sync`, or `darwin-rebuild`. They run this script for real.

## Commands you will need

Run from the repo root, on the macOS host.

| Purpose | Command | Expected on success |
|---|---|---|
| New check | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-cleanup-legacy-dotfiles'` | exit 0 |
| README guard | `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'` | exit 0 |
| Existing eval suite | `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| Format | `nix fmt -- --check modules/home/cleanup.nix tests/default.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `modules/home/cleanup.nix`
- `tests/unit/cleanup-legacy-dotfiles-test.sh` (create)
- `tests/default.nix` (add one registration)
- `tests/README.md` (add one table row)

**Out of scope** (do NOT touch):

- The list of `remove_legacy_path` entries. Do not delete entries. With the
  guard in place each entry is harmless, and a later plan can trim the list.
- `purge_stale_skill_dirs` at the end of the script.
- `modules/home/claude.nix`, `droid.nix`, `cursor.nix`.
- Issue #431 asks for broader tests of this script and the SSH guard. This plan
  adds only the test for this fix.

## Git workflow

- Branch: `advisor/009-cleanup-keeps-links-home-manager-owns`.
- One commit: `fix(cleanup): keep symlinks that already point into the Nix store`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Write the failing test

Create `tests/unit/cleanup-legacy-dotfiles-test.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

activation=$1
store_target=$2

fail() { echo "cleanup-legacy-dotfiles-test: $*" >&2; exit 1; }

case "$store_target" in
  /nix/store/*) ;;
  *) fail "fixture target must live in /nix/store, got $store_target" ;;
esac

HOME=$(mktemp -d)
export HOME
unset newGenPath

mkdir -p "$HOME/.local/bin" "$HOME/.claude/hooks" "$HOME/.claude/skills" "$HOME/outside"
ln -s "$store_target" "$HOME/.local/bin/claude"
echo stale >"$HOME/.local/bin/droid"
echo stale >"$HOME/outside/hook"
ln -s "$HOME/outside/hook" "$HOME/.claude/hooks/search-guard.sh"
ln -s "$store_target" "$HOME/.claude/skills/aily-md"

bash "$activation"

[ -L "$HOME/.local/bin/claude" ] || fail "deleted a symlink that resolves into /nix/store"
[ ! -e "$HOME/.local/bin/droid" ] || fail "kept a hand-placed plain file"
[ ! -L "$HOME/.claude/hooks/search-guard.sh" ] || fail "kept a symlink that points outside /nix/store"
[ ! -L "$HOME/.claude/skills/aily-md" ] || fail "kept a per-project skill link in a global picker dir"

echo "cleanup-legacy-dotfiles-test: all assertions passed"
```

### Step 2: Register the check

In `tests/default.nix`, directly after the line
`unit-claude-settings-ownership = callTest ./unit/claude-settings-ownership-test.nix { };`, add:

```nix
  unit-cleanup-legacy-dotfiles = onlyOn "darwin" "unit-cleanup-legacy-dotfiles"
    (shellTest "unit-cleanup-legacy-dotfiles" {
      script = ./unit/cleanup-legacy-dotfiles-test.sh;
      inputs = [ pkgs.coreutils pkgs.jq ];
      args = [
        (pkgs.writeText "cleanup-legacy-dotfiles.sh"
          self.darwinConfigurations."f".config.home-manager.users.martinfan.home.activation.cleanupLegacyDotfiles.data)
        "${pkgs.coreutils}/bin/true"
      ];
    });
```

In `tests/README.md`, add this row to the table under "What each test does",
after the `unit-claude-settings-ownership` row:

```markdown
| `unit-cleanup-legacy-dotfiles`      | Darwin-only: runs host "f"'s `cleanupLegacyDotfiles` activation text in a fixture home. A symlink into `/nix/store` survives, a hand-placed file and a non-store symlink are removed, and a per-project skill link is still pruned. |
```

Run `git add -N tests/unit/cleanup-legacy-dotfiles-test.sh`.

**Verify**: `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-cleanup-legacy-dotfiles'`
FAILS, and the log contains `deleted a symlink that resolves into /nix/store`.

### Step 3: Guard the delete helper

In `modules/home/cleanup.nix`, replace the `remove_legacy_path` function
(lines 8-12) with these two functions:

```nix
    remove_path() {
      if [ -e "$1" ] || [ -L "$1" ]; then
        rm -rf -- "$1"
      fi
    }

    remove_legacy_path() {
      if [ -L "$1" ]; then
        case "$(${pkgs.coreutils}/bin/readlink -f "$1" || true)" in
          /nix/store/*) return 0 ;;
        esac
      fi
      remove_path "$1"
    }
```

Then, inside the two skill-prune loops only (the `aily-md` loop and the
`hyperframes` loop shown in "Current state"), change the call
`remove_legacy_path` to `remove_path`. That is exactly two call sites. Every
other `remove_legacy_path` call stays as it is.

**Verify**: `rg -c 'remove_path "\$HOME/\$d/' modules/home/cleanup.nix` prints `2`.
`nix fmt -- --check modules/home/cleanup.nix tests/default.nix` exits 0.

### Step 4: Run the checks

**Verify**, all exit 0:

- `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-cleanup-legacy-dotfiles'`
- `nix build --no-link '.#checks.aarch64-darwin.unit-tests-readme'`
- `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'`

## Test plan

- New file `tests/unit/cleanup-legacy-dotfiles-test.sh`, four assertions:
  store link kept (the bug), plain file removed, non-store link removed,
  per-project skill link still pruned.
- It runs the real generated script for host "f", not a copy of it.
- Structural pattern: `tests/unit/auto-update-test.sh` for the `fail` helper.

## Done criteria

- [ ] The three commands in Step 4 exit 0
- [ ] `rg -c 'readlink -f' modules/home/cleanup.nix` prints `1`
- [ ] `rg -c 'remove_legacy_path "\$HOME' modules/home/cleanup.nix` prints the same count as before your edit minus 2
- [ ] `git status --short` lists only the four in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `modules/home/cleanup.nix:8-12` does not match the excerpt.
- The Step 2 check passes before Step 3. Then the bug is already fixed.
- The generated script fails in the sandbox for a reason other than the four
  assertions, for example an unset variable. Report the log line.
- `integration-configurations-eval` fails after Step 3. It asserts on the text
  of this script around `tests/integration/configurations-eval-test.nix:60-71`.
- The `doc-lock` hook blocks the `tests/README.md` edit.

## Maintenance notes

- The entry list can now be trimmed safely. An entry is dead once no machine
  still has a hand-placed file at that path.
- A reviewer should confirm the two prune loops still call the unguarded
  `remove_path`. Old skill links there point into the store on purpose.
- Deferred: an eval assertion that no `remove_legacy_path` target is also a
  `home.file` key. With the guard it is no longer needed for safety.
