#!/usr/bin/env bash
# Tier-1 hermetic check for martin.shell.viMode: renders the zshrc pieces,
# loads them in a real zsh inside the sandbox, and asserts on the actual
# keymap tables -- what each key resolves to after everything has loaded --
# rather than on zshrc source text or closure membership.
#
# Usage: SCENARIO=<name> zsh-vi-mode-test.sh <initContent-file> <zsh-vi-mode>
#                            <fzf> <zsh-autosuggestions> <zsh-syntax-highlighting>
#                            [fzf-git-sh]
# SCENARIO (env, default "default"): default | null-dirjump | off -- which
# martin.shell.search assertions run. The initContent sources fzf-git.sh
# inline (order 880); the package argument only pins it into this
# derivation's closure -- the script itself never reads it.
set -euo pipefail

init_content=$1
fzf_pkg=${2:-}
scenario=${SCENARIO:-default}
export scenario

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
  echo '# --- user initContent (native vi-mode + search + init) ---'
  cat "$init_content"
  echo '# --- HM order 910: fzf integration ---'
  if [[ -n "$fzf_pkg" && -x "$fzf_pkg/bin/fzf" ]]; then
    "$fzf_pkg/bin/fzf" --zsh > "$work/fzf-integration.zsh"
    echo "source '$work/fzf-integration.zsh'"
  fi
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

# ── martin.shell.search: prompt search plane (issue #329) ──
case $scenario in
default)
  # Every configured repo chord resolves to its widget in BOTH keymaps
  for km in viins vicmd; do
    expect_widget "$km" '^Gf' martin-content-search-widget
    expect_widget "$km" '^Gd' martin-dir-jump-widget
    expect_widget "$km" '^Gk' martin-process-kill-widget
  done
  ;;
null-dirjump)
  # Nulling one key leaves that chord unbound and the others intact.
  for km in viins vicmd; do
    out=$(bindkey -M "$km" -- '^Gd' 2>&1); read -r _ got <<<"$out"
    [[ -z $got || $got == undefined-key ]] || fail "null dirJump: ^Gd in $km bound to '$got', wanted unbound"
    expect_widget "$km" '^Gk' martin-process-kill-widget
    expect_widget "$km" '^Gf' martin-content-search-widget
  done
  ;;
off)
  # Disabling the feature leaves no picker widget bound anywhere.
  (( ! $+widgets[martin-content-search-widget] )) \
    || fail "martin-content-search-widget exists despite search.enable = false"
  for km in viins vicmd; do
    for k in '^Gf' '^Gd' '^Gk'; do
      out=$(bindkey -M "$km" -- "$k" 2>&1); read -r _ got <<<"$out"
      [[ -z $got || $got == undefined-key ]] || fail "search off: $k in $km bound to '$got'"
    done
  done
  ;;
*)
  print -u2 -- "unknown scenario: $scenario"
  exit 1
  ;;
esac

# The prefix alone resolves to NOTHING (or zle's "undefined-key" placeholder,
# which bindkey reports for an unbound sequence that is still a prefix of
# longer chords) in both keymaps. This is the assertion that keeps the plane
# out of the KEYTIMEOUT=1 race: an unbound pure prefix makes zsh wait
# indefinitely for the second key. Runs in default/null-dirjump -- with the
# feature OFF the stock list-expand binding legitimately remains.
prefix_pure() {
  local km=$1 out got
  out=$(bindkey -M "$km" -- '^G' 2>&1) || fail "querying ^G in $km failed"
  read -r _ got <<<"$out"
  [[ -z $got || $got == undefined-key ]] || fail "^G is bound to '$got' in $km -- reintroduces the key-timeout hazard"
}
[[ $scenario == off ]] || { prefix_pure viins; prefix_pure vicmd; }

expect_widget vicmd 'vv'   edit-command-line
expect_widget viins '^X^E' edit-command-line

bindkey -l | command grep -q '^vicmd$' || fail "vicmd keymap not listed"
bindkey -l | command grep -q '^viins$' || fail "viins keymap not listed"

# KEYTIMEOUT stays 1 (instant Escape)
[[ $KEYTIMEOUT == 1 ]] || fail "KEYTIMEOUT=$KEYTIMEOUT, wanted 1 (instant Escape)"
print "PASS unit-zsh-vi-mode ($scenario)"
ASSERTS

# -i: fzf's integration guards every bindkey behind `[[ -o interactive ]]`,
# and the contract must observe the post-fzf state; -f keeps rcs out.
zsh -f -i "$work/harness.zsh" </dev/null
echo "PASS unit-zsh-vi-mode driver"
