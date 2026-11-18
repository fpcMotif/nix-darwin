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
