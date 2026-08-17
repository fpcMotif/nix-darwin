#!/usr/bin/env bash
# Bump nubjs/nub prebuilt binary in pkgs/nub.nix.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/nub.nix"

latest=$(au_latest_github_release nubjs/nub)
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "nub already at $latest"; exit 0
fi

au_set_version "$FILE" "$latest"

url="https://github.com/nubjs/nub/releases/download/v${latest}/nub-darwin-arm64.tar.gz"
au_set_block_hash "$FILE" "releases/download" "$(au_prefetch_sri "$url")"

au_build_darwin .#martin.nub
au_report_change nub "$current" "$latest"
