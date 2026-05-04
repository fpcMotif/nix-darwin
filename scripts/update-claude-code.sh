#!/usr/bin/env bash
# Bump the sadjow/claude-code-nix flake input.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

before=$(jq -r '.nodes."claude-code".locked.rev // ""' flake.lock)
nix flake update claude-code 2>&1 | tail -50
after=$(jq -r '.nodes."claude-code".locked.rev // ""' flake.lock)

if [ "$before" = "$after" ]; then
  echo "claude-code already at $after"
  exit 0
fi
echo "claude-code bumped: $before -> $after"
