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

FILE="pkgs/droid.nix"

latest=$(curl -fsSL "https://registry.npmjs.org/@factory%2fcli-darwin-arm64" \
           | jq -r '."dist-tags".latest // ""')
[ -n "$latest" ] && [ "$latest" != null ] || {
  echo "update-droid: empty latest dist-tag" >&2; exit 1
}

current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "droid already at $latest"; exit 0
fi
echo "droid: $current -> $latest"

au_set_version "$FILE" "$latest"

# Anchor each hash on its version-free npm package name (unique per block);
# never anchor on the URL's ${version} segment — perl \Q\E would interpolate
# it empty and silently no-op the bump.
for pkg in \
  cli-darwin-arm64 \
  cli-darwin-x64-baseline \
  cli-linux-arm64 \
  cli-linux-x64-baseline
do
  url="https://registry.npmjs.org/@factory/${pkg}/-/${pkg}-${latest}.tgz"
  sri=$(au_prefetch_sri "$url")
  au_set_block_hash "$FILE" "$pkg" "$sri"
done

echo "droid bumped to $latest"
