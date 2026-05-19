#!/usr/bin/env bash
# Bump pkgs/zed-nightly-bin.nix by following the zed.dev "nightly" channel
# redirect chain.
#
# `https://zed.dev/api/releases/nightly/latest/Zed-aarch64.dmg` 307s to
# `https://cloud.zed.dev/...` which in turn 302s to
# `https://zed-nightly-host.nyc3.digitaloceanspaces.com/${version}/Zed-aarch64.dmg`.
# We grab that final URL, lift the `${version}` path segment as the pin, then
# prefetch the asset for its SRI hash.
#
# The nightly channel doesn't tag, doesn't expose a JSON manifest, and the
# version string in the URL is `1.4.0+nightly.<seq>.<sha>` — verbatim — so
# updates are URL-driven, not GitHub-driven.
#
# Platforms: aarch64-darwin only, matching pkgs/zed-nightly-bin.nix and the
# flake's supportedSystems list. See the header in pkgs/zed-nightly-bin.nix
# for what to change if Intel-Mac support is added back.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/zed-nightly-bin.nix"

resolve_final_url() {
  # `nightly/latest/<asset>` goes through two hops (zed.dev → cloud.zed.dev →
  # nyc3.digitaloceanspaces.com). `curl -sLI` only emits the first Location
  # header on some HEAD chains, so use a tiny ranged GET to force redirect
  # following and print the effective URL.
  curl -sL "https://cloud.zed.dev/releases/nightly/latest/download?asset=zed&os=macos&arch=$1" \
       -o /dev/null -w "%{url_effective}\n" --range 0-0
}

final_aarch64=$(resolve_final_url aarch64)

# Strip leading "https://.../" and trailing "/Zed-*.dmg" → the version segment.
# Uses `#` as the s/// delimiter so the `|` inside the alternation is safe.
extract_version() {
  printf '%s\n' "$1" | sed -E 's#^https?://[^/]+/##; s#/Zed-(aarch64|x86_64)\.dmg$##'
}

latest=$(extract_version "$final_aarch64")
# Sanity: the version segment must look like Zed's nightly format, otherwise
# the redirect chain has changed and we shouldn't bake a garbage string in.
case "$latest" in
  *+nightly.*) ;;
  *)
    echo "zed-nightly: unexpected version shape from $final_aarch64: '$latest'" >&2
    exit 1 ;;
esac

current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "zed-nightly already at $latest"; exit 0
fi
echo "zed-nightly: $current -> $latest"

# Prefetch into an explicit variable BEFORE mutating the Nix file. A
# command substitution passed straight into au_set_block_hash would, under
# Bash's `set -e`, swallow a transient prefetch failure and silently write
# an empty string in place of the pinned hash. Validate the SRI shape too
# so a future au_prefetch_sri regression can't blank the pin either.
hash_aarch64=$(au_prefetch_sri "$final_aarch64")
case "$hash_aarch64" in
  sha256-?*) ;;
  *)
    echo "zed-nightly: invalid SRI hash for aarch64-darwin: '$hash_aarch64'" >&2
    exit 1 ;;
esac

au_set_version "$FILE" "$latest"
au_set_block_hash "$FILE" '"aarch64-darwin"' "$hash_aarch64"

au_build .#legacyPackages.aarch64-darwin.martin.zed-nightly-bin
echo "zed-nightly bumped to $latest"
