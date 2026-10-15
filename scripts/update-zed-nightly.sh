#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/zed-nightly-bin.nix"

resolve_dmg_url() {
  local arch=$1
  local channel_url="https://cloud.zed.dev/releases/nightly/latest/download?asset=zed&os=macos&arch=$arch"
  # AGENTS.md requires ax for HTTP.
  if command -v ax >/dev/null 2>&1; then
    ax "$channel_url" --max-bytes 1 | jq -r .url
  else
    curl -sL "$channel_url" -o /dev/null -w "%{url_effective}\n" --range 0-0
  fi
}

# The nightly channel has no tags or JSON manifest, only a redirect to
# `<host>/<version>/Zed-aarch64.dmg`.
version_from_dmg_url() {
  local dmg_url=$1
  printf '%s\n' "$dmg_url" | sed -E 's#^https?://[^/]+/##; s#/Zed-(aarch64|x86_64)\.dmg$##'
}

# flake.nix's supportedSystems skips x86_64-darwin, so an Intel pin would never
# reach CI or any host.
dmg_url=$(resolve_dmg_url aarch64)
latest=$(version_from_dmg_url "$dmg_url")
# A different shape means the redirect chain changed.
case "$latest" in
  *+nightly.*) ;;
  *)
    echo "zed-nightly: unexpected version shape from $dmg_url: '$latest'" >&2
    exit 1 ;;
esac

au_bump_release --name zed-nightly --file "$FILE" --version "$latest" \
  --attr .#legacyPackages.aarch64-darwin.martin.zed-nightly-bin \
  --asset "$dmg_url" '"aarch64-darwin"'
