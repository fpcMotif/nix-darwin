#!/usr/bin/env bash
# Bump the sadjow/claude-code-nix flake input.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

before=$(jq -r '.nodes."claude-code".locked.rev // ""' flake.lock)
nix flake update claude-code --commit-lock-file=false
after=$(jq -r '.nodes."claude-code".locked.rev // ""' flake.lock)

if [ "$before" = "$after" ]; then
  echo "claude-code already at $after"
  exit 0
fi

echo "claude-code bumped: $before -> $after"
