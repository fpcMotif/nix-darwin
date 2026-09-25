#!/usr/bin/env bash
# Tier-1 hermetic check for martin.shell.interactive = "fish": copies the
# generated ~/.config into a scratch HOME, runs a real fish in every startup
# mode, and asserts on what those processes observably do -- PATH, exported
# variables, exit status, quiet output, key bindings, wrappers, direnv, and
# zoxide -- not on config source text.
#
# Usage: fish-shell-test.sh <home-files> <session-path-file>
#   <home-files>         the HM home-files output (tests/lib/shell-home.nix)
#   <session-path-file>  home.sessionPath, one entry per line ($HOME/$USER unexpanded)
# fish, bash, direnv, zoxide, and jq come from PATH.
#
# Single-quoted arguments are fish code; fish expands their variables.
# shellcheck disable=SC2016
set -euo pipefail

home_files=$1
session_path_file=$2

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
pass() { printf 'PASS %s\n' "$1"; }

# fish resets USER from the passwd entry, so use the real one.
USER=$(id -un)
export HOME="$work/home" USER LOGNAME="$USER" TERM=xterm-256color
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
# No system or vendor fish config may leak in, and the live host's
# /etc/fish (nix-darwin) is skipped through its own guards.
export XDG_DATA_DIRS="$work/share"
export __NIX_DARWIN_SET_ENVIRONMENT_DONE=1
export __fish_nix_darwin_general_config_sourced=1
export __fish_nix_darwin_login_config_sourced=1
export __fish_nix_darwin_interactive_config_sourced=1
unset TERMINFO_DIRS __HM_SESS_VARS_SOURCED
# fish's first interactive start scans man pages in the background unless
# this cache exists; the scan would race the scratch cleanup.
mkdir -p "$HOME" "$XDG_DATA_HOME" "$work/share" "$XDG_CACHE_HOME/fish/generated_completions"
cp -RL "$home_files/.config" "$XDG_CONFIG_HOME"
chmod -R u+w "$XDG_CONFIG_HOME"

bash_bin=$(command -v bash)
fish_bin=$(command -v fish)

# Recording stubs: each writes its argv and the AI env it received, then
# exits with the status its name asks for. Nothing real is ever called.
stubs="$work/stubs"
mkdir -p "$stubs" "$HOME/.local/bin"
make_stub() { # $1 = path, $2 = exit status
  cat >"$1" <<EOF
#!$bash_bin
{
  for a in "\$@"; do printf 'ARG:%s\n' "\$a"; done
  env | grep -E '^(ANTHROPIC_API_KEY|CLAUDE_CODE_EFFORT_LEVEL|OPENAI_API_KEY)=' | sed 's/^/ENV:/'
} >"$work/rec.\$(basename "\$0")"
exit $2
EOF
  chmod +x "$1"
}
for name in zsh codex opencode pi amp with-cliproxy dust; do
  make_stub "$stubs/$name" 0
done
make_stub "$HOME/.local/bin/claude" 7
export PATH="$stubs:$PATH"

# The session tiers put real profile directories ahead of the stubs, so
# wrapper tests reset PATH to the stubs plus the few tools they need. No
# real AI CLI is reachable there.
tools="$work/tools"
mkdir -p "$tools"
for t in env jq grep sed basename; do
  ln -s "$(command -v "$t")" "$tools/$t"
done
isolate="set -gx PATH $stubs $tools;"

rec() { cat "$work/rec.$1" 2>/dev/null || true; }
args() { rec "$1" | grep '^ARG:' | cut -d: -f2- || true; }
envof() { rec "$1" | grep "^ENV:$2=" | cut -d= -f2- || true; }

# run MODE CMD: runs fish, leaving stdout in $out, stderr in $err, status in $rc.
run() {
  set +e
  "$fish_bin" "$1" "$2" </dev/null >"$work/out" 2>"$work/err"
  rc=$?
  set -e
  out=$(cat "$work/out")
  err=$(cat "$work/err")
}

modes=(-c -lc -ic -lic)

# ── startup: generated config loads, output stays clean, status propagates ──
for mode in "${modes[@]}"; do
  run "$mode" 'exit'
  [[ $rc == 0 && -z $out && -z $err ]] \
    || fail "fish $mode 'exit': rc=$rc stdout='$out' stderr='$err' (wanted 0 and silence)"

  run "$mode" 'set -q __fish_home_manager_config_sourced; and echo loaded'
  [[ $out == loaded ]] || fail "fish $mode did not load the generated config.fish"
done
pass "startup: all four modes load the generated config and stay silent"

for mode in -ic -lic; do
  run "$mode" 'functions -q martin-content-search; and abbr --query gst; and echo interactive'
  [[ $out == interactive ]] || fail "fish $mode did not reach the interactive config (functions, abbreviations)"
done
run -c 'abbr --query gst; and echo leaked'
[[ -z $out ]] || fail "abbreviations leaked into non-interactive fish -c"
pass "startup: interactive config only in interactive modes"

run -c 'exit 3'
[[ $rc == 3 ]] || fail "fish -c 'exit 3' returned $rc"
run -lic 'false'
[[ $rc == 1 ]] || fail "fish -lic 'false' returned $rc"
pass "startup: exit status propagates"

[[ ! -e $work/rec.zsh ]] || fail "fish startup launched zsh"
# The stub only catches a PATH lookup that reaches it, so also check every
# fish file startup reads -- config.fish, its functions, and the store files
# it sources -- for any non-comment zsh reference.
fish_dir="$XDG_CONFIG_HOME/fish"
mapfile -t sourced < <(grep -oE 'source /nix/store/[^ ;]+' "$fish_dir/config.fish" | cut -d' ' -f2)
for f in "$fish_dir/config.fish" "$fish_dir"/functions/*.fish "${sourced[@]}"; do
  if grep -v '^[[:space:]]*#' "$f" | grep -qw zsh; then
    fail "fish startup file $f references zsh"
  fi
done
pass "startup: no mode launches or sources zsh"

# ── PATH: duplicate-free, session tiers first and in order, stable in children ──
expected=()
while IFS= read -r entry || [[ -n $entry ]]; do
  [[ -n $entry ]] || continue
  expected+=("$(HOME=$HOME USER=$USER eval "printf '%s' \"$entry\"")")
done <"$session_path_file"

check_path() { # $1 = label, $2 = newline-joined PATH
  local label=$1
  local -a entries=() seen_order=()
  local -A seen=()
  mapfile -t entries <<<"$2"
  local e
  for e in "${entries[@]}"; do
    [[ -z ${seen[$e]+x} ]] || fail "$label: PATH repeats '$e'"
    seen[$e]=1
  done
  [[ ${entries[0]} == "${expected[0]}" ]] \
    || fail "$label: PATH starts with '${entries[0]}', wanted tier head '${expected[0]}'"
  for e in "${entries[@]}"; do
    local x
    for x in "${expected[@]}"; do
      [[ $e == "$x" ]] && seen_order+=("$e")
    done
  done
  [[ "${seen_order[*]}" == "${expected[*]}" ]] \
    || fail "$label: session tiers out of order: ${seen_order[*]}"
}

for mode in "${modes[@]}"; do
  run "$mode" 'string join \n -- $PATH'
  check_path "fish $mode (clean)" "$out"
done

# Children inherit a login fish's exports, including the session guard.
cat >"$work/parent.fish" <<EOF
string join \n -- \$PATH > $work/parent.path
for m in -c -lc -ic -lic
    $fish_bin \$m 'string join \n -- \$PATH' > $work/child\$m.path </dev/null
end
EOF
run -lc "source $work/parent.fish"
[[ $rc == 0 && -z $err ]] || fail "inherited parent failed: rc=$rc stderr='$err'"
for mode in "${modes[@]}"; do
  check_path "fish $mode (inherited)" "$(cat "$work/child$mode.path")"
  cmp -s "$work/parent.path" "$work/child$mode.path" \
    || fail "fish $mode forked from a login fish changed PATH"
done
pass "PATH: duplicate-free with session tiers in order, clean and inherited"

# ── exported session variables and terminfo ──
run -c 'env | grep -E "^(EDITOR|TERMINFO)="'
[[ $out == *"EDITOR=nvim"* && $out == *"TERMINFO=$HOME/.terminfo"* ]] \
  || fail "session variables not exported to children: '$out'"
if [[ $(uname) == Darwin ]]; then
  run -c 'echo $SHELL'
  [[ $out == /run/current-system/sw/bin/fish ]] || fail "SHELL='$out', wanted the fish login shell"
fi

terminfo_dirs=$(TERMINFO_DIRS="/usr/share/terminfo:/inherited/terminfo::" "$fish_bin" -c 'echo $TERMINFO_DIRS' </dev/null)
IFS=: read -r -a terminfo_entries <<<"$terminfo_dirs"
declare -A terminfo_seen=()
for e in "${terminfo_entries[@]}"; do
  [[ -n $e && -z ${terminfo_seen[$e]+x} ]] || fail "TERMINFO_DIRS='$terminfo_dirs' has an empty or repeated entry"
  terminfo_seen[$e]=1
done
[[ ${terminfo_entries[0]} == "$HOME/.terminfo" && -n ${terminfo_seen[/inherited/terminfo]+x} ]] \
  || fail "TERMINFO_DIRS='$terminfo_dirs': wanted ~/.terminfo first and the inherited entry kept"
pass "environment: session variables exported, inherited terminfo kept"

# ── key bindings, after the first-prompt load fish performs ──
# __fish_config_interactive is what fish runs before its first prompt.
binds=$("$fish_bin" -ic '__fish_config_interactive >/dev/null
echo keymap=$fish_key_bindings
for spec in "insert ctrl-g,f" "default ctrl-g,f" "insert ctrl-g,d" "insert ctrl-g,k" "default ctrl-g,k" \
        "insert ctrl-g,ctrl-b" "insert ctrl-r" "default ctrl-r" "insert ctrl-t" "insert alt-c" \
        "insert ctrl-a" "insert ctrl-e" "insert ctrl-u" "insert ctrl-p" "insert ctrl-n" \
        "insert ctrl-k" "insert alt-e" "default alt-e"
    set -l parts (string split " " $spec)
    # A user binding beats a preset on the same key; report the one that wins.
    set -l b (bind --user -M $parts[1] $parts[2] 2>/dev/null)
    or set b (bind --preset -M $parts[1] $parts[2] 2>/dev/null)
    echo "$spec => $(string split -f2 -m1 " $parts[2] " -- $b[-1])"
end
for spec in "insert ctrl-g" "default ctrl-g" "insert ctrl-g,b" "default ctrl-g,h"
    set -l parts (string split " " $spec)
    bind -M $parts[1] $parts[2] >/dev/null 2>&1; and echo "$spec => BOUND"; or echo "$spec => unbound"
end' </dev/null 2>/dev/null | awk '{ gsub(/\033\[[0-9 ]*q/, ""); print }')  # vi cursor-shape escapes

expect_bind() { # $1 = "mode key", $2 = command
  grep -Fxq "$1 => $2" <<<"$binds" || fail "binding '$1' is not '$2' -- got: $(grep -F "$1 =>" <<<"$binds")"
}
grep -Fxq 'keymap=fish_vi_key_bindings' <<<"$binds" || fail "fish_key_bindings is not vi"
expect_bind "insert ctrl-g,f" martin-content-search
expect_bind "default ctrl-g,f" martin-content-search
expect_bind "insert ctrl-g,d" martin-dir-jump
expect_bind "insert ctrl-g,k" martin-process-kill
expect_bind "default ctrl-g,k" martin-process-kill
expect_bind "insert ctrl-g,ctrl-b" "'__fzf_git_sh branches'"
expect_bind "insert ctrl-r" fzf-history-widget
expect_bind "default ctrl-r" fzf-history-widget
expect_bind "insert ctrl-t" fzf-file-widget
expect_bind "insert alt-c" fzf-cd-widget
expect_bind "insert ctrl-a" beginning-of-line
expect_bind "insert ctrl-e" end-of-line
expect_bind "insert ctrl-u" kill-whole-line
expect_bind "insert ctrl-p" up-or-search
expect_bind "insert ctrl-n" down-or-search
expect_bind "insert ctrl-k" kill-line
expect_bind "insert alt-e" edit_command_buffer
expect_bind "default alt-e" edit_command_buffer
# The prefix alone stays unbound, so chords never wait on an ambiguous key.
expect_bind "insert ctrl-g" unbound
expect_bind "default ctrl-g" unbound
# Plain git letters give way to this repo's pickers; ctrl-letter git chords stay.
expect_bind "insert ctrl-g,b" unbound
expect_bind "default ctrl-g,h" unbound
pass "bindings: vi keymap, search plane, fzf, and insert-mode reflexes"

# ── abbreviations and helpers ──
run -ic 'for a in gst ls cat grep dotdot reload; abbr --query $a; or exit 9; end; __martin_multicd ...'
[[ $rc == 0 && $out == "cd ../../" ]] || fail "abbreviations or dot navigation broken: rc=$rc out='$out'"

run -ic "$isolate"'du -h other'
[[ $(args dust) == 'other' ]] || fail "du -h should call dust with only the path, got: $(args dust)"
run -ic "$isolate"'du -sh "some dir"'
[[ $(args dust) == $'-d\n0\nsome dir' ]] || fail "du -sh should call dust -d 0, got: $(args dust)"
pass "helpers: abbreviations, dot navigation, and du"

# ── command lookup: names the interactive helpers shadow stay real in scripts ──
# (fish ships its own grep color wrapper; this config only abbreviates grep.)
run -c 'type -t claude cc codex opencode amp crush droid pi du ab jot vault 2>/dev/null'
[[ $out != *function* ]] || fail "fish -c resolves a shadowed name to a function: $(tr '\n' ' ' <<<"$out")"
run -ic 'type -t claude cc codex opencode pi du'
[[ $out == $'function\nfunction\nfunction\nfunction\nfunction\nfunction' ]] \
  || fail "interactive fish lacks a wrapper: $(tr '\n' ' ' <<<"$out")"
pass "lookup: wrappers are interactive-only; scripts find the real commands"

# ── AI wrappers: argv intact, exit status kept, env removed from the child only ──
run -ic "$isolate"'set -gx ANTHROPIC_API_KEY parent-secret
set -gx CLAUDE_CODE_EFFORT_LEVEL xhigh
claude "two words" plain
echo status=$status
echo parent=$ANTHROPIC_API_KEY/$CLAUDE_CODE_EFFORT_LEVEL'
[[ $out == $'status=7\nparent=parent-secret/xhigh' ]] || fail "claude wrapper lost the exit status or touched the parent env: '$out'"
[[ $(args claude) == $'--settings\n{"ultracode":true}\ntwo words\nplain' ]] \
  || fail "claude wrapper argv wrong: $(args claude)"
[[ -z $(envof claude ANTHROPIC_API_KEY) && -z $(envof claude CLAUDE_CODE_EFFORT_LEVEL) ]] \
  || fail "claude wrapper leaked the AI env or effort floor: $(rec claude)"

run -ic "$isolate"'set -gx ANTHROPIC_API_KEY parent-secret; cc x'
[[ $(args claude) == $'--dangerously-skip-permissions\n--settings\n{"ultracode":true}\nx' ]] \
  || fail "cc should run cofficial with bypass: $(args claude)"
[[ -z $(envof claude ANTHROPIC_API_KEY) ]] || fail "cc leaked ANTHROPIC_API_KEY"

run -ic "$isolate"'codex "a b"'
[[ $(args codex) == 'a b' ]] || fail "codex wrapper should fall back to codex: $(args codex)"

run -ic "$isolate"'set -gx ANTHROPIC_API_KEY k; opencode run "a b"'
[[ $(args with-cliproxy) == $'opencode\nrun\na b' && $(envof with-cliproxy ANTHROPIC_API_KEY) == k ]] \
  || fail "opencode should route through with-cliproxy by default: $(rec with-cliproxy)"

printf '{"opencode":"direct","pi":"direct"}\n' >"$XDG_CONFIG_HOME/climode.json"
run -ic "$isolate"'set -gx ANTHROPIC_API_KEY k; opencode run'
[[ $(args opencode) == run && $(envof opencode ANTHROPIC_API_KEY) == k ]] \
  || fail "direct opencode should keep env: $(rec opencode)"
run -ic "$isolate"'set -gx ANTHROPIC_API_KEY k; pi go'
[[ $(args pi) == go && -z $(envof pi ANTHROPIC_API_KEY) ]] || fail "direct pi should clear the AI env: $(rec pi)"
run -ic "$isolate"'set -gx OPENAI_API_KEY k; amp login'
[[ $(args amp) == login && -z $(envof amp OPENAI_API_KEY) ]] || fail "amp login should clear the AI env: $(rec amp)"
pass "wrappers: argv, exit status, and child-only env isolation"

# ── direnv: entering a project loads it, leaving restores the session ──
proj="$work/proj"
mkdir -p "$proj"
printf 'export MARTIN_DIRENV_PROBE=inside\nexport MARTIN_DIRENV_KEEP=inner\n' >"$proj/.envrc"
direnv allow "$proj" 2>/dev/null
run -ic "set -gx MARTIN_DIRENV_KEEP outer
cd $proj; __direnv_export_eval
echo \"in=\$MARTIN_DIRENV_PROBE/\$MARTIN_DIRENV_KEEP\"
cd $work; __direnv_export_eval
echo \"out=[\$MARTIN_DIRENV_PROBE]/\$MARTIN_DIRENV_KEEP\""
[[ $out == $'in=inside/inner\nout=[]/outer' ]] || fail "direnv entry/exit: '$out' stderr='$err'"
pass "direnv: project environment loads and unloads"

# ── zoxide and the other integrations ──
zoxide add "$proj"
run -ic "z proj; pwd; functions -q y wt; and echo ok"
[[ $out == "$proj"$'\nok' ]] || fail "zoxide z or the y/wt functions are missing: '$out' stderr='$err'"
pass "integrations: zoxide, yazi, and worktrunk"

# ── prompt: builtins only, status and vi mode visible ──
# A directory without .envrc, so direnv's cd hook stays quiet.
mkdir -p "$work/promptdir"
run -ic "__fish_config_interactive >/dev/null
cd $work/promptdir
set -lx PATH /nonexistent
true; fish_prompt; echo
false; fish_prompt; echo
set fish_bind_mode default; fish_prompt"
[[ -z $err ]] || fail "fish_prompt ran an external command: $err"
mapfile -t prompts <<<"$out"
[[ ${prompts[0]} == *promptdir* && ${prompts[0]} == *$'\e[32m❯'* ]] || fail "success prompt wrong: '${prompts[0]}'"
[[ ${prompts[1]} == *$'\e[31m❯'* ]] || fail "failure prompt should color the arrow red: '${prompts[1]}'"
[[ ${prompts[2]} == *'❮'* ]] || fail "vi normal mode should flip the arrow: '${prompts[2]}'"
pass "prompt: no external commands, status and mode shown"

[[ ! -e $work/rec.zsh ]] || fail "a fish session launched zsh"
echo "PASS unit-fish-shell"
