#!/usr/bin/env bash
# Bump tw93/Mole (mo / mole) in pkgs/mole.nix. Mole tags use a capital `V`
# prefix (V1.39.0), unlike the standard `v` lower-case convention.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/mole.nix"

latest=$(au_latest_github_release tw93/Mole '^V')
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "mole already at $latest"; exit 0
fi
echo "mole: $current -> $latest"

au_set_version "$FILE" "$latest"

src_url="https://github.com/tw93/Mole/archive/refs/tags/V${latest}.tar.gz"
analyze_url="https://github.com/tw93/Mole/releases/download/V${latest}/analyze-darwin-arm64"
status_url="https://github.com/tw93/Mole/releases/download/V${latest}/status-darwin-arm64"

# src uses fetchzip → unpacked hash.
au_set_block_hash "$FILE" "tags/V\${version}.tar.gz" "$(au_prefetch_unpacked_sri "$src_url")"
au_set_block_hash "$FILE" "/analyze-darwin-arm64"   "$(au_prefetch_sri        "$analyze_url")"
au_set_block_hash "$FILE" "/status-darwin-arm64"    "$(au_prefetch_sri        "$status_url")"

au_build .#martin.mole
echo "mole bumped to $latest"
