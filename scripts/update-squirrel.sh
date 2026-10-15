#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

# rime/squirrel's rolling `latest` tag makes `tag_name` the literal "latest",
# so the version comes from the asset file name.
latest=$(
  au_github_api "https://api.github.com/repos/rime/squirrel/releases/latest" \
    | jq -r '.assets[].name' \
    | grep -oE 'Squirrel-[0-9.]+\.pkg' \
    | head -1 \
    | sed -E 's|Squirrel-([0-9.]+)\.pkg|\1|'
)
[ -n "$latest" ] || { echo "squirrel: could not parse version from asset name" >&2; exit 1; }

au_bump_release --name squirrel --file pkgs/squirrel.nix --version "$latest" \
  --attr .#martin.squirrel \
  --asset "https://github.com/rime/squirrel/releases/download/${latest}/Squirrel-${latest}.pkg" 'rime/squirrel/releases/download/'
