#!/usr/bin/env bash
# Bump Hammerspoon/hammerspoon in pkgs/hammerspoon.nix. Tags carry no `v`
# prefix — the default `^v` strip pattern leaves them untouched.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release Hammerspoon/hammerspoon)

au_bump_release --name hammerspoon --file pkgs/hammerspoon.nix --version "$latest" \
  --attr .#martin.hammerspoon \
  --asset "https://github.com/Hammerspoon/hammerspoon/releases/download/${latest}/Hammerspoon-${latest}.zip" 'Hammerspoon/hammerspoon/releases/download/'
