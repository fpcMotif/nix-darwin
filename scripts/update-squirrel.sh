#!/usr/bin/env bash
# Bump rime/squirrel (Rime input method frontend) in pkgs/squirrel.nix.
#
# rime/squirrel uses a rolling `latest` git tag, so `tag_name` from the GH
# API is literally "latest" and unusable. The real version lives in the
# release asset filename: `Squirrel-<x.y.z>.pkg`.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/squirrel.nix"

# Optimization: Single `jq` call handles JSON extraction, regex match, capture, and filtering.
# This eliminates spawning `grep`, `head`, and `sed` subprocesses on every update run.
latest=$(
  curl -fsSL "https://api.github.com/repos/rime/squirrel/releases/latest" \
    | jq -r '[.assets[].name | select(test("Squirrel-[0-9.]+\\.pkg")) | capture("Squirrel-(?<version>[0-9.]+)\\.pkg") | .version][0] // ""'
)
[ -n "$latest" ] || { echo "squirrel: could not parse version from asset name" >&2; exit 1; }

current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "squirrel already at $latest"; exit 0
fi
echo "squirrel: $current -> $latest"

url="https://github.com/rime/squirrel/releases/download/${latest}/Squirrel-${latest}.pkg"
sri=$(au_prefetch_sri "$url")

au_set_version "$FILE" "$latest"
au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|"

au_build .#martin.squirrel
echo "squirrel bumped to $latest"
