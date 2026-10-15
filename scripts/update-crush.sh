#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

# `nur` is a heavy input (issue #336), and this script bumps it outside
# update-flake-inputs.sh.
if ! au_inputs_to_bump "$(au_today_weekday)" nur | grep -qxF nur; then
  echo "crush: nur is heavy and today is not cadence day ($AU_CADENCE_DAY) — deferring"
  exit 0
fi

crush_version() {
  nix eval --raw .#crush.version 2>/dev/null || nix eval --raw .#crush.name
}

before=$(crush_version)
nix flake update nur 2>&1 | tail -10
au_build .#crush

after=$(crush_version)
if [ "$before" = "$after" ]; then
  echo "crush already at $after"
else
  au_report_change crush "$before" "$after"
fi
