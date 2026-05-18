#!/usr/bin/env bash
# Bump Raycast in pkgs/raycast.nix.
#
# `api.raycast.com/v2/download?build=universal` 302-redirects to a CF Worker
# URL that 403s on plain HEAD without browser-style headers — so we read only
# the first hop (no `-L`), where the next hop's URL is URL-encoded inside the
# `?url=` query string. That URL embeds the build filename
# `Raycast_v<x.y.z>_<sha>_universal.dmg`.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/raycast.nix"

latest=$(
  curl -fsSI "https://api.raycast.com/v2/download?build=universal" \
    | tr -d '\r' \
    | grep -i '^location:' \
    | head -1 \
    | grep -oE 'Raycast_v[0-9.]+(_|%5F)' \
    | head -1 \
    | sed -E 's|Raycast_v([0-9.]+).*|\1|'
)
[ -n "$latest" ] || { echo "raycast: could not parse version from redirect" >&2; exit 1; }

current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "raycast already at $latest"; exit 0
fi
echo "raycast: $current -> $latest"

url="https://releases.raycast.com/releases/${latest}/download?build=universal"
sri=$(au_prefetch_sri "$url")

au_set_version "$FILE" "$latest"
au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|"

au_build .#martin.raycast
echo "raycast bumped to $latest"
