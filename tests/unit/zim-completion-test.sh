#!/usr/bin/env bash
# Load the Zim completionInit in a sandboxed zsh and check what the Zim
# completion module owns: compinit runs once, the dump is cached and
# compiled, and a completion added to fpath rebuilds the dump. The last
# property is the reason to use Zim here: `compinit -C` alone reuses a
# stale dump after a switch adds completions.
set -euo pipefail

completion_init="$1"

fail() {
  echo "zim-completion-test: $1" >&2
  exit 1
}

HOME=$(mktemp -d)
export HOME
export TERM=xterm-256color
comp_dir="$HOME/.zsh/completions"
mkdir -p "$comp_dir"
printf '#compdef zimone\n' > "$comp_dir/_zimone"

# Prints the registered completion for $1, and fails on any stderr output.
load() {
  local err="$HOME/load.stderr"
  zsh -f -c "fpath=('$comp_dir' \$fpath); source '$completion_init'; print -r -- \${_comps[$1]-}" 2>"$err"
  if [ -s "$err" ]; then
    cat "$err" >&2
    fail "loading completionInit wrote to stderr"
  fi
}

[ "$(load zimone)" = _zimone ] || fail "first load did not register _zimone"
[ -s "$HOME/.zcompdump" ] || fail "dump missing after first load"

# An unchanged fpath must reuse the dump rather than rebuild it.
printf '# reuse-marker\n' >> "$HOME/.zcompdump"
[ "$(load zimone)" = _zimone ] || fail "second load did not register _zimone"
grep -q reuse-marker "$HOME/.zcompdump" || fail "unchanged fpath rebuilt the dump"

# A completion added to fpath, as after a switch, must appear on the next load.
printf '#compdef zimtwo\n' > "$comp_dir/_zimtwo"
[ "$(load zimtwo)" = _zimtwo ] || fail "new completion on fpath was not picked up"
[ -s "$HOME/.zcompdump.zwc" ] || fail "compiled dump missing"

zstyle_menu=$(zsh -f -c "source '$completion_init'; zstyle -L ':completion:*' menu" 2>/dev/null)
case "$zstyle_menu" in
  *select*) ;;
  *) fail "completion zstyles were not applied" ;;
esac

echo "zim-completion-test: ok"
