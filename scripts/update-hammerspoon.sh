#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

# Hammerspoon tags have no `v` prefix, so the default `^v` strip is a no-op.
latest=$(au_latest_github_release Hammerspoon/hammerspoon)

au_bump_release --name hammerspoon --file pkgs/hammerspoon.nix --version "$latest" \
  --attr .#martin.hammerspoon \
  --asset "https://github.com/Hammerspoon/hammerspoon/releases/download/${latest}/Hammerspoon-${latest}.zip" 'Hammerspoon/hammerspoon/releases/download/'
