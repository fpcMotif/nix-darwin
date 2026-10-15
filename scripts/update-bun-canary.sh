#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

# bun re-uploads the GitHub `canary` asset at one URL several times a day, and
# a hash pinned to it goes stale within hours. npm versions are immutable.
latest=$(au_http_get "https://registry.npmjs.org/-/package/@oven%2fbun-darwin-aarch64/dist-tags" \
           | jq -r '.canary // ""')
[[ $latest =~ -canary\.([0-9]{8})\.[0-9]+$ ]] || {
  echo "bun-canary: unexpected npm canary version '$latest'" >&2
  exit 1
}
build_date=${BASH_REMATCH[1]}

# GNU date on the Linux runner, BSD date on macOS.
week_ago=$(date -u -d '7 days ago' +%Y%m%d 2>/dev/null || date -u -v-7d +%Y%m%d)
# npm can stop receiving canaries for months while the pin stays valid but old.
if [ "$build_date" -lt "$week_ago" ]; then
  echo "bun-canary: npm's newest canary $latest is over a week old; bun may have stopped publishing canaries to npm" >&2
  exit 1
fi

au_bump_release --name bun-canary --file pkgs/bun-canary-bin.nix --version "$latest" \
  --attr .#legacyPackages.aarch64-darwin.martin.bun-canary-bin \
  --asset "https://registry.npmjs.org/@oven/bun-darwin-aarch64/-/bun-darwin-aarch64-${latest}.tgz" '"aarch64-darwin"'
