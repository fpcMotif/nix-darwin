#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

crush_version() {
  nix eval --raw .#crush.version 2>/dev/null || nix eval --raw .#crush.name
}

before=$(crush_version)
nix flake update charm-nur 2>&1 | tail -10
au_build .#crush

after=$(crush_version)
if [ "$before" = "$after" ]; then
  echo "crush already at $after"
else
  au_report_change crush "$before" "$after"
fi
