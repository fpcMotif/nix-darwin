#!/usr/bin/env bash
# Bump the prebuilt Hunk release (pkgs/hunk-bin.nix) to the latest stable
# modem-dev/hunk tag. Stable channel only: betas stay behind.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/hunk-bin.nix"

latest=$(au_latest_github_release modem-dev/hunk)
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "hunk already at $latest"; exit 0
fi

au_set_version "$FILE" "$latest"

asset="hunkdiff-darwin-arm64.tar.gz"
url="https://github.com/modem-dev/hunk/releases/download/v${latest}/${asset}"
echo "  hunk: $asset"
au_set_block_hash "$FILE" "/${asset}\"" "$(au_prefetch_sri "$url")"

au_build_darwin .#martin.hunk-bin
au_report_change hunk "$current" "$latest"
