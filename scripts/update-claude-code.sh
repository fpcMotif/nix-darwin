#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

locked_rev() {
  jq -r '.nodes."claude-code".locked.rev // ""' flake.lock
}

before=$(locked_rev)
nix flake update claude-code 2>&1 | tail -50
after=$(locked_rev)

if [ "$before" = "$after" ]; then
  echo "claude-code already at $after"
  exit 0
fi
au_report_change claude-code "$before" "$after"
