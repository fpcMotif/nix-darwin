#!/usr/bin/env bash
# Refresh Crush through the official Charm NUR package. NUR ships its own
# updater, so we just bump the `nur` flake input and re-eval. The general
# update-flake-inputs.sh would also bump `nur`, but this script narrows the
# fetch and surfaces the resolved `crush.version` for the PR log.
#
# `nur` is a HEAVY input (issue #336): it moves only on the cadence day so
# this sibling script cannot quietly bypass the nightly's classification.
# AU_FORCE_FULL_BUMP=1 overrides, as everywhere else.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

if ! au_inputs_to_bump "$(au_today_weekday)" nur | grep -qxF nur; then
  echo "crush: nur is heavy and today is not cadence day ($AU_CADENCE_DAY) — deferring"
  exit 0
fi

before=$(nix eval --raw .#crush.version 2>/dev/null \
         || nix eval --raw .#crush.name)
nix flake update nur 2>&1 | tail -10
au_build .#crush

after=$(nix eval --raw .#crush.version 2>/dev/null \
        || nix eval --raw .#crush.name)
if [ "$before" = "$after" ]; then
  echo "crush already at $after"
else
  au_report_change crush "$before" "$after"
fi
