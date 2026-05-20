#!/usr/bin/env bash
# Bump Dropbox macOS client in pkgs/dropbox.nix.
#
# Dropbox's public download endpoint 302-redirects to the current installer
# with the build number in the `build_no=` query param of the Location
# header. We deliberately do NOT pass `&full=1` — that variant redirects to a
# filename-only URL with no build_no, which would require a second parse pass.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/dropbox.nix"

latest=$(
  curl -fsSI "https://www.dropbox.com/download?plat=mac" \
    | tr -d '\r' \
    | grep -i '^location:' \
    | head -1 \
    | grep -oE 'build_no=[0-9.]+' \
    | head -1 \
    | cut -d= -f2
)
[ -n "$latest" ] || { echo "dropbox: could not parse build_no from redirect" >&2; exit 1; }

current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "dropbox already at $latest"; exit 0
fi
echo "dropbox: $current -> $latest"

url="https://edge.dropboxstatic.com/dbx-releng/client/Dropbox%20${latest}.dmg"
sri=$(au_prefetch_sri "$url")

au_set_version "$FILE" "$latest"
au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|"

au_build .#martin.dropbox
echo "dropbox bumped to $latest"
