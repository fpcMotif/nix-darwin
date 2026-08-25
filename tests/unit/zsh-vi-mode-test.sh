#!/usr/bin/env bash
# Tier-1 hermetic check for martin.shell.viMode: renders the zshrc pieces,
# loads them in a real zsh inside the sandbox, and asserts on the actual
# keymap tables -- what each key resolves to after everything has loaded --
# rather than on zshrc source text or closure membership.
#
# Usage: zsh-vi-mode-test.sh <initContent-file> <zsh-vi-mode> <fzf>
#                            <zsh-autosuggestions> <zsh-syntax-highlighting>
set -euo pipefail

init_content=$1
zvm_pkg=$2
fzf_pkg=$3
autosuggestions_pkg=$4
syntax_pkg=$5

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export HOME="$work/home" ZDOTDIR="$work/zdot" TERM=xterm-256color
mkdir -p "$HOME" "$ZDOTDIR"

# Emulate home-manager's .zshrc section order around the user's initContent:
#   order 530   bindkey -v            (programs.zsh.defaultKeymap = "viins")
#   order 700   zsh-autosuggestions   (programs.zsh.autosuggestion.enable)
#   <user initContent>                (modules/home/zsh.nix; its vi-mode block
#                                      exports the ZVM_* variables and registers
#                                      _martin_zle_binds BEFORE order 900)
#   order 900   plugins               (zsh-vi-mode; ZVM_INIT_MODE=sourcing makes
#                                      zvm_init run here, which resets all
#                                      keymaps and then runs the registered hook)
#   order 910   fzf integration       ("fzf --zsh", materialized to a file)
#   order 1200  syntax highlighting   (must stay last)
{
  echo '# --- HM order 530: default keymap ---'
  echo 'bindkey -v'
  echo '# --- HM order 700: autosuggestions ---'
  echo "source '$autosuggestions_pkg/share/zsh-autosuggestions/zsh-autosuggestions.zsh'"
  echo '# --- user initContent (vi-mode wiring + legacy init) ---'
  cat "$init_content"
  echo '# --- HM order 900: plugins ---'
  echo "source '$zvm_pkg/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh'"
  echo '# --- HM order 910: fzf integration ---'
  "$fzf_pkg/bin/fzf" --zsh > "$work/fzf-integration.zsh"
  echo "source '$work/fzf-integration.zsh'"
  echo '# --- HM order 1200: syntax highlighting ---'
  echo "source '$syntax_pkg/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'"
} > "$work/harness.zsh"

cat >> "$work/harness.zsh" <<'ASSERTS'

fail() { print -u2 -- "FAIL: $1"; exit 1 }

# The load-bearing regression this whole design exists to prevent:
# zsh-vi-mode's re-initialization must not eat any binding this repo owns.
expect_widget() {
  local km=$1 out got
  shift
  out=$(bindkey -M "$km" -- "$1" 2>&1) || fail "$1 unbound in $km (wanted $2)"
  read -r _ got <<<"$out"
  [[ $got == "$2" ]] || fail "$1 in $km bound to '$got', wanted '$2'"
}

# The load-bearing regression this whole design exists to prevent:
# zsh-vi-mode's re-initialization must not eat any binding this repo owns.
for km in viins vicmd; do
  expect_widget "$km" '^R'  fzf-history-widget
  expect_widget "$km" '^T'  fzf-file-widget
  expect_widget "$km" '^[c' fzf-cd-widget
  # Prefix history Up/Down, both cursor-key encodings (normal + application).
  expect_widget "$km" '^[[A' up-line-or-beginning-search
  expect_widget "$km" '^[OA' up-line-or-beginning-search
  expect_widget "$km" '^[[B' down-line-or-beginning-search
  expect_widget "$km" '^[OB' down-line-or-beginning-search
  # fn-Delete must never again type a literal ~ (the historical regression),
  # and Home/End/PageUp/PageDown/Shift-Tab keep their widgets in both keymaps.
  expect_widget "$km" '^[[3~' delete-char
  expect_widget "$km" '^[[H'  beginning-of-line
  expect_widget "$km" '^[[F'  end-of-line
  expect_widget "$km" '^[[5~' beginning-of-buffer-or-history
  expect_widget "$km" '^[[6~' end-of-buffer-or-history
  expect_widget "$km" '^[[Z'  reverse-menu-complete
done

# keepEmacsKeys contract: the surviving emacs reflexes live in viins only
# (^P/^N arrive via the both-keymap prefix binds asserted above).
expect_viins() { expect_widget viins "$@"; }
expect_viins '^A' beginning-of-line
expect_viins '^E' end-of-line
expect_viins '^K' kill-line
expect_viins '^U' kill-whole-line
expect_viins '^W' backward-kill-word
expect_viins '^P' up-line-or-beginning-search
expect_viins '^N' down-line-or-beginning-search

# Editor chord: vv from normal mode, ^X^E straight from insert; bare v stays
# with the plugin (nex readkeys prefix for visual/chords).
out=$(bindkey -M vicmd -- 'v') || fail "v unbound in vicmd"
read -r _ got <<<"$out"
case $got in
  zvm_*) ;;
  *) fail "bare v in vicmd bound to '$got', wanted a zvm widget" ;;
esac
expect_widget vicmd 'vv'   edit-command-line
expect_widget viins '^X^E' edit-command-line

# The plugin's own surface is present (modes, operators, repeat, surround).
for w in zvm_enter_insert_mode zvm_exit_insert_mode zvm_enter_visual_mode \
         zvm_repeat_change zvm_select_surround zvm_change_surround \
         zvm_change_surround_text_object zvm_vi_edit_command_line; do
  (( $+widgets[$w] )) || fail "plugin widget missing: $w"
done
bindkey -l | command grep -q '^vicmd$' || fail "vicmd keymap not listed"
bindkey -l | command grep -q '^viins$' || fail "viins keymap not listed"

# zsh-autosuggestions must still be wired after the plugin re-initializes:
# its start function exists AND its precmd registration survived.
(( $+functions[_zsh_autosuggest_start] )) \
  || fail "zsh-autosuggestions start function lost after zvm_init"
(( ${precmd_functions[(I)_zsh_autosuggest_start]} )) \
  || fail "zsh-autosuggestions precmd hook detached by zvm_init"

# Timeouts and mode flags: KEYTIMEOUT stays 1 (instant Escape); the plugin's
# escape window comes from ZVM_KEYTIMEOUT instead.
[[ $KEYTIMEOUT == 1 ]] || fail "KEYTIMEOUT=$KEYTIMEOUT, wanted 1 (instant Escape)"
[[ $ZVM_INIT_MODE == sourcing ]] || fail "ZVM_INIT_MODE=$ZVM_INIT_MODE, wanted sourcing"
[[ $ZVM_LAZY_KEYBINDINGS == false ]] || fail "ZVM_LAZY_KEYBINDINGS=$ZVM_LAZY_KEYBINDINGS, wanted false"

# Cursor shapes: enabled, beam/block/block per the option defaults.
[[ $ZVM_CURSOR_STYLE_ENABLED == true ]] || fail "cursor styles unexpectedly disabled"
[[ $ZVM_INSERT_MODE_CURSOR == be ]] || fail "insert cursor '$ZVM_INSERT_MODE_CURSOR', wanted be"
[[ $ZVM_NORMAL_MODE_CURSOR == bl ]] || fail "normal cursor '$ZVM_NORMAL_MODE_CURSOR', wanted bl"
[[ $ZVM_VISUAL_MODE_CURSOR == bl ]] || fail "visual cursor '$ZVM_VISUAL_MODE_CURSOR', wanted bl"

print "PASS unit-zsh-vi-mode"
ASSERTS

# -i: fzf's integration guards every bindkey behind `[[ -o interactive ]]`,
# and the contract must observe the post-fzf state; -f keeps rcs out.
zsh -f -i "$work/harness.zsh" </dev/null
