#!/usr/bin/env bash
# Refresh Crush through the official Charm NUR package. NUR ships its own
# updater, so we just bump the `nur` flake input and re-eval. The general
# update-flake-inputs.sh would also bump `nur`, but this script narrows the
# fetch and surfaces the resolved `crush.version` for the PR log.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

nix flake update nur 2>&1 | tail -10
au_build .#crush

ver=$(nix eval --raw .#crush.version 2>/dev/null \
       || nix eval --raw .#crush.name)
echo "crush refreshed via Charm NUR at ${ver}"
