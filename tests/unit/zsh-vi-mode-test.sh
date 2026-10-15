#!/usr/bin/env bash
set -euo pipefail

init_content=$1
fzf_pkg=${2:-}
scenario=${SCENARIO:-default}
export scenario

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export HOME="$work/home" ZDOTDIR="$work/zdot" TERM=xterm-256color
mkdir -p "$HOME" "$ZDOTDIR"

# Home Manager places `bindkey -v` (order 530) before the user initContent and
# the fzf integration (order 910) after it. The bindings must survive that order.
{
  echo 'bindkey -v'
  cat "$init_content"
  if [[ -n "$fzf_pkg" && -x "$fzf_pkg/bin/fzf" ]]; then
    "$fzf_pkg/bin/fzf" --zsh > "$work/fzf-integration.zsh"
    echo "source '$work/fzf-integration.zsh'"
  fi
} > "$work/harness.zsh"

# Zshrc source text and closure membership miss bindings that later code overrides.
cat >>"$work/harness.zsh" <<'ASSERTS'

fail() { print -u2 -- "FAIL: $1"; exit 1 }

expect_widget() {
  local keymap_name=$1 key=$2 want=$3 out got
  out=$(bindkey -M "$keymap_name" -- "$key" 2>&1) || fail "$key unbound in $keymap_name (wanted $want)"
  read -r _ got <<<"$out"
  [[ $got == "$want" ]] || fail "$key in $keymap_name bound to '$got', wanted '$want'"
}

# bindkey reports "undefined-key" for an unbound sequence that still prefixes
# longer chords.
expect_unbound() {
  local keymap_name=$1 key=$2 reason=$3 out got
  out=$(bindkey -M "$keymap_name" -- "$key" 2>&1) || fail "querying $key in $keymap_name failed"
  read -r _ got <<<"$out"
  [[ -z $got || $got == undefined-key ]] || fail "$key in $keymap_name bound to '$got': $reason"
}

# zsh-vi-mode re-initializes every keymap. It must not eat a binding this repo owns.
for keymap_name in viins vicmd; do
  expect_widget "$keymap_name" '^R'  fzf-history-widget
  expect_widget "$keymap_name" '^T'  fzf-file-widget
  expect_widget "$keymap_name" '^[c' fzf-cd-widget
  # Terminals send either the normal or the application cursor-key encoding.
  expect_widget "$keymap_name" '^[[A' up-line-or-beginning-search
  expect_widget "$keymap_name" '^[OA' up-line-or-beginning-search
  expect_widget "$keymap_name" '^[[B' down-line-or-beginning-search
  expect_widget "$keymap_name" '^[OB' down-line-or-beginning-search
  # Without this binding, fn-Delete types a literal ~.
  expect_widget "$keymap_name" '^[[3~' delete-char
  expect_widget "$keymap_name" '^[[H'  beginning-of-line
  expect_widget "$keymap_name" '^[[F'  end-of-line
  expect_widget "$keymap_name" '^[[5~' beginning-of-buffer-or-history
  expect_widget "$keymap_name" '^[[6~' end-of-buffer-or-history
  expect_widget "$keymap_name" '^[[Z'  reverse-menu-complete
done

# keepEmacsKeys keeps these emacs reflexes in viins only.
expect_widget viins '^A' beginning-of-line
expect_widget viins '^E' end-of-line
expect_widget viins '^K' kill-line
expect_widget viins '^U' kill-whole-line
expect_widget viins '^W' backward-kill-word
expect_widget viins '^P' up-line-or-beginning-search
expect_widget viins '^N' down-line-or-beginning-search

# Issue #329 puts the martin.shell.search widgets under the ^G prefix.
case $scenario in
default)
  for keymap_name in viins vicmd; do
    expect_widget "$keymap_name" '^Gf' martin-content-search-widget
    expect_widget "$keymap_name" '^Gd' martin-dir-jump-widget
    expect_widget "$keymap_name" '^Gk' martin-process-kill-widget
  done
  ;;
null-dirjump)
  for keymap_name in viins vicmd; do
    expect_unbound "$keymap_name" '^Gd' "null dirJump wants it unbound"
    expect_widget "$keymap_name" '^Gk' martin-process-kill-widget
    expect_widget "$keymap_name" '^Gf' martin-content-search-widget
  done
  ;;
off)
  (( ! $+widgets[martin-content-search-widget] )) \
    || fail "martin-content-search-widget exists despite search.enable = false"
  for keymap_name in viins vicmd; do
    for key in '^Gf' '^Gd' '^Gk'; do
      expect_unbound "$keymap_name" "$key" "search off wants it unbound"
    done
  done
  ;;
*)
  print -u2 -- "unknown scenario: $scenario"
  exit 1
  ;;
esac

# A bound ^G prefix races the second key under KEYTIMEOUT=1. With search off,
# the stock list-expand binding legitimately remains.
if [[ $scenario != off ]]; then
  for keymap_name in viins vicmd; do
    expect_unbound "$keymap_name" '^G' "reintroduces the key-timeout hazard"
  done
fi

expect_widget vicmd 'vv'   edit-command-line
expect_widget viins '^X^E' edit-command-line

bindkey -l | command grep -q '^vicmd$' || fail "vicmd keymap not listed"
bindkey -l | command grep -q '^viins$' || fail "viins keymap not listed"

[[ $KEYTIMEOUT == 1 ]] || fail "KEYTIMEOUT=$KEYTIMEOUT, wanted 1 (instant Escape)"
print "PASS unit-zsh-vi-mode ($scenario)"
ASSERTS

# -i: fzf's integration guards every bindkey behind `[[ -o interactive ]]`,
# and the contract must observe the post-fzf state. -f keeps rcs out.
zsh -f -i "$work/harness.zsh" </dev/null
echo "PASS unit-zsh-vi-mode driver"
