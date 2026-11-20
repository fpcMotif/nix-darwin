# Plan 011: Remove the parked skhd Ghostty helpers and their host config

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report. Do not improvise. When done, update the status row for this plan
> in `plans/README.md`, unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 534fc39..HEAD -- modules/home/shell/zsh.nix hosts/darwin/default.nix HOTKEYS.md modules/darwin/skhd.nix`
> If any of these changed, compare the "Current state" excerpts against the
> live code. On a mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none.
- **Decision**: REJECTED on 2026-11-18. The maintainer keeps the skhd code. Do not execute this plan.
- **Category**: tech-debt
- **Planned at**: commit `534fc39`, 2026-11-17

## Decision gate (read before anything else)

`HOTKEYS.md:21-24` says this code is kept on purpose:

> `modules/darwin/skhd.nix` and the `martin.skhd.extraConfig` block in
> `hosts/darwin/default.nix` are intentionally kept intact, so re-enabling is a
> one-line flip — but it needs a fix for the BetterMouse tap conflict first

So this is a parked feature, not an accident. **Execute this plan only if the
operator has confirmed, in the request that dispatched you, that skhd is not
coming back.** If you were not told that, stop and report "plan 011 needs the
maintainer's decision".

## At a glance

skhd is forced off on this host because it conflicts with BetterMouse, and a
test locks that in. Two zsh functions and 45 lines of host config still exist
only to drive skhd. This plan deletes them and updates `HOTKEYS.md`. The skhd
module itself and Ghostty's native keybinds are unchanged.

## Why this matters

`gsp` and `gpn` are shell aliases that always fail with exit code 127 and the
message "skhd is not on PATH". The host config block is never rendered into a
running service. Both cost reading time and must be kept in sync with Ghostty's
keybinds for no effect.

## Current state

Files:

- `modules/home/shell/zsh.nix` — zsh aliases and init text.
- `hosts/darwin/default.nix` — host options, including `martin.skhd`.
- `modules/darwin/skhd.nix` — the skhd module. Not edited.
- `HOTKEYS.md` — documents the hotkeys and the parked state.
- `tests/integration/darwin-settings-test.nix:221-224` — asserts skhd stays off.

`modules/home/shell/zsh.nix:168-170` today (inside the alias attrset):

```nix
        sg = "ast-grep";
        gsp = "ghostty-split";
        gpn = "ghostty-pane";
```

`modules/home/shell/zsh.nix:427-433` today (inside the init text):

```zsh
        _ghostty_key() {
          if ! (( $+commands[skhd] )); then
            print -u2 "ghostty: skhd is not on PATH; run sync or use Ghostty's native keybinds"
            return 127
          fi
          command skhd -k "$1"
        }
```

It is followed by `ghostty-split() { ... }` (lines 435-449) and
`ghostty-pane() { ... }` (lines 451-465). Each ends with `_ghostty_key "$chord"`
and a closing `}`. The next function after them starts with `ab() {`.

`hosts/darwin/default.nix:39-45` today:

```nix
    skhd = {
      # Keep skhd off because its event tap conflicts with BetterMouse.
      enable = false;
      # Add personal bindings here. skhd syntax: `mod - key : command`.
      # Global prefix `ctrl + alt + shift` is reserved by the defaults.
      extraConfig = ''
        # Ghostty split controls.
```

The `extraConfig` string runs to the closing `'';` on line 89. It holds eight
bindings, each of the form:

```text
        ctrl + alt + shift - e [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd - d"
          * : open -a "Ghostty"
        ]
```

`tests/integration/darwin-settings-test.nix:221-224`:

```nix
    (helpers.assertTest "darwin-settings-skhd-disabled"
      (cfg.martin.skhd.enable == false
        && cfg.services.skhd.enable == false)
      "skhd should stay disabled while BetterMouse owns the event tap")
```

`HOTKEYS.md` mentions the helpers and the block at lines 19-20, 22-24, 61-62,
64-83, and 166. Line 19 names the wrong file, `modules/home/zsh.nix`. The real
path is `modules/home/shell/zsh.nix`.

Other references, from `rg -n 'ghostty-split|ghostty-pane|_ghostty_key|gsp|gpn'`
outside `plans/` and `references/`: only the three files above.

Repo rules that apply:

- A `doc-lock` hook blocks new or changed code comments and Markdown outside
  docs work. This plan edits `HOTKEYS.md`. If the hook blocks it, stop and
  report. A comment may be deleted together with the code it describes.
- Agent shells here deny `cd`, `sed`, `find`, and bare `python`.
- Never run `just switch`, `just sync`, or `darwin-rebuild`.

## Commands you will need

Run from the repo root.

| Purpose | Command | Expected on success |
|---|---|---|
| zsh keymap test | `nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-zsh-vi-mode'` | exit 0 |
| Host settings | `nix build --no-link '.#checks.aarch64-darwin.integration-darwin-settings'` | exit 0 |
| Host eval | `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'` | exit 0 |
| Doc links | `nix build --no-link '.#checks.aarch64-darwin.unit-doc-links'` | exit 0 |
| Format | `nix fmt -- --check modules/home/shell/zsh.nix hosts/darwin/default.nix` | exit 0 |

## Scope

**In scope** (the only files you may modify):

- `modules/home/shell/zsh.nix`
- `hosts/darwin/default.nix`
- `HOTKEYS.md`

**Out of scope** (do NOT touch):

- `modules/darwin/skhd.nix`. The module and its `extraConfig` option stay, so
  skhd can return later.
- `enable = false;` and its comment in the host file. Keep both.
- `modules/home/ghostty.nix`. Its native keybinds already cover split and pane moves.
- `tests/integration/darwin-settings-test.nix`.

## Git workflow

- Branch: `advisor/011-remove-parked-skhd-ghostty-helpers`.
- One commit: `chore(skhd): drop the Ghostty helpers that only work with skhd on`.
- Do NOT push or open a PR unless the operator told you to.

## Steps

### Step 1: Remove the zsh helpers

In `modules/home/shell/zsh.nix`:

1. Delete the two alias lines `gsp = "ghostty-split";` and `gpn = "ghostty-pane";`.
2. Delete the three functions `_ghostty_key`, `ghostty-split`, and
   `ghostty-pane`, from the line `_ghostty_key() {` through the closing `}` of
   `ghostty-pane`, plus one of the blank lines around them so that exactly one
   blank line separates the function before them from `ab() {`.

**Verify**: `rg -n 'ghostty-split|ghostty-pane|_ghostty_key|gsp|gpn' modules/home/shell/zsh.nix` prints nothing.
`nix build --no-link --print-build-logs '.#checks.aarch64-darwin.unit-zsh-vi-mode'` exits 0.

### Step 2: Remove the host config block

In `hosts/darwin/default.nix`, reduce the `skhd` block to:

```nix
    skhd = {
      # Keep skhd off because its event tap conflicts with BetterMouse.
      enable = false;
    };
```

That deletes the two comment lines above `extraConfig` and the whole
`extraConfig = '' ... '';` string.

**Verify**: `rg -n 'extraConfig|skhd -k' hosts/darwin/default.nix` prints nothing.
`rg -n 'pkgs' hosts/darwin/default.nix` — if `pkgs` is now unused in the file,
run `nix develop --command deadnix --fail hosts/darwin/default.nix`. If it
reports an unused `pkgs` argument, remove `pkgs` from the function header.

### Step 3: Update HOTKEYS.md

Edit `HOTKEYS.md` so it describes the new state:

1. Delete the bullet at lines 19-20 that starts
   ``- The `gsp` / `gpn` shell helpers``.
2. Rewrite the sentence at lines 22-24 to say that `modules/darwin/skhd.nix`
   is kept so the service can be re-enabled, and that the Ghostty forwarding
   bindings were removed and would need to be re-added under
   `martin.skhd.extraConfig`.
3. Delete the section `## Ghostty Global Split Hotkeys` (lines 64-83), from its
   heading through the line that starts `Terminal equivalents from the shell:`.
4. Delete the line 166 that starts `Terminal commands: `.

Keep the sentence at lines 61-62 about adding host bindings under
`martin.skhd.extraConfig`. The option still exists.

**Verify**: `rg -n 'gsp|gpn|Ghostty Global Split' HOTKEYS.md` prints nothing.

### Step 4: Run the checks

**Verify**, all exit 0:

- `nix build --no-link '.#checks.aarch64-darwin.integration-darwin-settings'`
- `nix build --no-link '.#checks.aarch64-darwin.integration-configurations-eval'`
- `nix build --no-link '.#checks.aarch64-darwin.unit-doc-links'`
- `nix fmt -- --check modules/home/shell/zsh.nix hosts/darwin/default.nix`

## Test plan

- No new test. The behaviour removed was a guaranteed failure path.
- `integration-darwin-settings` already asserts that skhd stays off.
- `unit-zsh-vi-mode` loads the rendered zsh init and proves it still parses.

## Done criteria

- [ ] `rg -n 'ghostty-split|ghostty-pane|_ghostty_key|\bgsp\b|\bgpn\b' --glob '!plans/**' --glob '!references/**' .` returns no matches
- [ ] The four commands in Step 4 exit 0
- [ ] `git diff --stat` shows only the three in-scope files (plus files already modified before you started)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- You were not told that the maintainer confirmed skhd is not coming back.
- `cfg.martin.skhd.enable` is `true` anywhere under `hosts/`.
- Any file outside the three in scope references `gsp`, `gpn`, or the functions.
- The `doc-lock` hook blocks the `HOTKEYS.md` edit.

## Maintenance notes

- To bring the global Ghostty hotkeys back, restore the `extraConfig` block
  from commit `534fc39` of `hosts/darwin/default.nix` and fix the BetterMouse
  event-tap conflict first.
- A reviewer should confirm that Ghostty's own `cmd+d` and `cmd+alt+arrow`
  keybinds in `modules/home/ghostty.nix` are untouched.
