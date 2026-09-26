#!/usr/bin/env bash
# Bump pkgs/bun-canary-bin.nix to bun's newest npm canary.
#
# bun publishes one immutable canary a day to npm, named
# <last stable>-canary.<YYYYMMDD>.<n> under the `canary` dist-tag. The version
# selects the tarball URL, so this is a release pin: au_bump_release moves the
# version and hash together. See pkgs/bun-canary-bin.nix for why the GitHub
# `canary` asset is not used.
#
# npm published no canary from 2026-05-19 to 2026-08-20. A stall leaves the pin
# valid but old, so refuse a canary built more than a week ago: the nightly run
# then reports this updater as failed instead of passing quietly.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_http_get "https://registry.npmjs.org/-/package/@oven%2fbun-darwin-aarch64/dist-tags" \
           | jq -r '.canary // ""')
[[ $latest =~ -canary\.([0-9]{8})\.[0-9]+$ ]] || {
  echo "bun-canary: unexpected npm canary version '$latest'" >&2
  exit 1
}
built=${BASH_REMATCH[1]}

# GNU date on the Linux runner, BSD date on macOS.
cutoff=$(date -u -d '7 days ago' +%Y%m%d 2>/dev/null || date -u -v-7d +%Y%m%d)
if [ "$built" -lt "$cutoff" ]; then
  echo "bun-canary: npm's newest canary $latest is over a week old; bun may have stopped publishing canaries to npm" >&2
  exit 1
fi

au_bump_release --name bun-canary --file pkgs/bun-canary-bin.nix --version "$latest" \
  --attr .#legacyPackages.aarch64-darwin.martin.bun-canary-bin \
  --asset "https://registry.npmjs.org/@oven/bun-darwin-aarch64/-/bun-darwin-aarch64-${latest}.tgz" '"aarch64-darwin"'
