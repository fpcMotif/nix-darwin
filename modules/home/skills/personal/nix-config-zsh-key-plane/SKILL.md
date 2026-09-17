---
name: nix-config-zsh-key-plane
description: "Add or modify a zsh ZLE key plane / fzf picker binding in the nix-config repo: option wiring, zsh-vi-mode-safe binding order, widget classes, Ghostty typing veneer, and which test seam to extend. Use when touching martin.shell.search, adding chords/pickers under ^G, or extending the rendered-zshrc unit seam."
---

# zsh key planes in nix-config (martin.shell.search pattern)

Reference implementation: `modules/home/zsh.nix` (^G plane), `modules/home/ghostty.nix` (veneer), tests in `tests/unit/zsh-vi-mode-test.sh` + `tests/lib/zsh-module-eval.nix`.

## Binding order inside `_martin_zle_binds` (load-bearing)

1. Bind two-key chords FIRST via `_bindk`/`_martin_bk` (→ `zvm_bindkey` under vi mode). `zvm_bindkey` raw-binds the full chord AND registers the first key as `zvm_readkeys_handler`.
2. THEN strip the prefix (`bindkey -rM`) from every managed keymap. Verified safe: removing the handler leaves the full chord working through zsh's native multi-key sequences, and later zvm binds do NOT re-register it.
3. Strip upstream's plain-letter fallbacks (`^gX`) for object letters you don't own — fzf-git.sh self-binds BOTH `^g^x` and plain `^gx`.
4. Re-run upstream's installer inside the hook after zsh-vi-mode resets keymaps (upstream issue #23): guard `$+functions[__fzf_git_init]`, call with LITERAL args (`'?list_bindings'` must keep its shell quotes; baking them into a Nix list interpolation creates garbage widget names).

Never bind chords without then removing the bare prefix: zsh ships `^G → list-expand` in viins/vicmd by default, and with KEYTIMEOUT=1 a bound-and-prefix key races a 10ms window. Unbound pure prefix = zsh waits indefinitely.

## Empirical ZLE facts (verified, do not re-litigate)

- Nested `vared` inside a running widget FAILS: "ZLE cannot be used recursively (yet)". For query input, seed from `${LBUFFER##*[[:space:]]}` and fall back to `zle -M` guidance.
- Full-screen pickers in widgets: capture via `$(...)` BEFORE `zle -I`, insert into LBUFFER, then `zle reset-prompt`. Cancel path must touch BUFFER not at all.
- `bindkey -M km -- '^X'` on an unbound key prints `"^X" undefined-key`, rc=0. Assert unbound as `-z $got || $got == undefined-key`.
- Widget invocation can only be tested from real ZLE; headless harnesses assert keymap tables only. Behavioral checks need a pty driver (`expect`) and even then only non-vared paths work.
- In zsh glob patterns held in VARIABLES, `\?` does NOT match literal `?`; bare `?` does.

## nixpkgs fzf-git.sh quirks

- Package patches widget names to `<fzfStoreBin>/fzf-git-<obj>-widget`. Assertions must match by suffix (`[[ $got == *fzf-git-branches-widget ]]`). Object list: files branches tags remotes hashes stashes lreflogs each_ref worktrees '?list_bindings'.
- The '?' help widget name contains a literal `?`: match with bare-glob suffix `?list_bindings`.

## Test seam conventions

- Unit tier (`unit-zsh-vi-mode`): harness cats evaluated `programs.zsh.initContent` between HM order markers (530 bindkey -v, 700 autosuggestions, initContent, 900 plugins, 910 fzf --zsh, 1200 syntax). Scenario variants come from `tests/lib/zsh-module-eval.nix` overrides; select scenario via ENV VAR (`SCENARIO=... bash script ...`), never positional args — empty Nix string interpolations collapse argument positions. Export the variable: the assertions run in a zsh CHILD process.
- Eval tier (`integration-configurations-eval-test.nix`): toggle checks via the shim's explicit params; baseline/uniqueness checks parse generated text (`keybind = TRIGGER=` up to first `=`).
- Ghostty veneer bytes: `text:\xNN` Zig escapes, two hex digits; repo chords derive from `search.prefix`, but anything driving UPSTREAM stays fixed `\x07\x02` (upstream owns ^G regardless of the prefix option).
- After editing tips/copy emitted from options: rebuild, then `zsh -n` the generated initContent — interpolated array elements silently lose shell quotes if you forget escaped `\"`.

## Verify

```
nix build --no-link '.#darwinConfigurations.f.system' \
  '.#checks.aarch64-darwin.unit-zsh-vi-mode' \
  '.#checks.aarch64-darwin.integration-configurations-eval'
nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).darwinConfigurations.f.config.home-manager.users.martinfan.programs.zsh.initContent' | zsh -n
```
