#!/usr/bin/env bash
# Bump Factory AI's droid CLI by polling the npm registry for the
# @factory/cli-darwin-arm64 package version, then refreshing per-platform
# hashes in pkgs/droid.nix.
#
# Why npm (not Factory's downloads CDN): the npm registry mirrors every
# release as @factory/cli-${PLATFORM} tarballs with a single Bun-compiled
# binary at package/bin/droid, and is much more stable across CI than
# downloads.factory.ai.
#
# pkgs/droid.nix templates URLs with `${version}`, so prefetching is a
# direct `nix-prefetch-url` call per platform — no fake-hash dance.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/droid.nix"

latest=$(au_latest_npm "@factory/cli-darwin-arm64")
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "droid already at $latest"; exit 0
fi
echo "droid: $current -> $latest"

au_set_version "$FILE" "$latest"

declare -A urls=(
  [aarch64-darwin]="https://registry.npmjs.org/@factory/cli-darwin-arm64/-/cli-darwin-arm64-${latest}.tgz"
  [x86_64-darwin]="https://registry.npmjs.org/@factory/cli-darwin-x64-baseline/-/cli-darwin-x64-baseline-${latest}.tgz"
  [aarch64-linux]="https://registry.npmjs.org/@factory/cli-linux-arm64/-/cli-linux-arm64-${latest}.tgz"
  [x86_64-linux]="https://registry.npmjs.org/@factory/cli-linux-x64-baseline/-/cli-linux-x64-baseline-${latest}.tgz"
)

for plat in "${!urls[@]}"; do
  echo "  $plat"
  au_set_block_hash "$FILE" "\"${plat}\"" "$(au_prefetch_sri "${urls[$plat]}")"
done

au_build .#martin.droid
echo "droid bumped to $latest"
