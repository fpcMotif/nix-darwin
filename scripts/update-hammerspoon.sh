#!/usr/bin/env bash
# Bump Hammerspoon/hammerspoon in pkgs/hammerspoon.nix. Tags carry no `v`
# prefix — the default `^v` strip pattern leaves them untouched.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/hammerspoon.nix"

latest=$(au_latest_github_release Hammerspoon/hammerspoon)
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "hammerspoon already at $latest"; exit 0
fi
echo "hammerspoon: $current -> $latest"

url="https://github.com/Hammerspoon/hammerspoon/releases/download/${latest}/Hammerspoon-${latest}.zip"
sri=$(au_prefetch_sri "$url")

au_set_version "$FILE" "$latest"
au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|"

au_build .#martin.hammerspoon
echo "hammerspoon bumped to $latest"
