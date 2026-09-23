#!/usr/bin/env bash
# Bump the Factory Droid CLI in pkgs/droid.nix.
#
# Factory publishes per-platform binary-only npm packages (@factory/cli-*).
# They share one version and only a stable `latest` dist-tag, so query it
# directly rather than via au_latest_npm's bleeding-edge priority list.
# pkgs/droid.nix re-signs the binary ad-hoc at build time (Factory's
# linker-signed sig is invalid from the read-only Nix store), so a plain
# version+hash bump is all that's needed here.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_http_get "https://registry.npmjs.org/@factory%2fcli-darwin-arm64" \
           | jq -r '."dist-tags".latest // ""')

# Anchor each hash on its version-free npm package name (unique per block).
assets=()
for pkg in cli-darwin-arm64 cli-darwin-x64-baseline cli-linux-arm64 cli-linux-x64-baseline; do
  assets+=(--asset "https://registry.npmjs.org/@factory/${pkg}/-/${pkg}-${latest}.tgz" "$pkg")
done

au_bump_release --name droid --file pkgs/droid.nix --version "$latest" \
  --attr .#martin.droid "${assets[@]}"
