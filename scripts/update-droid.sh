#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

# Factory's per-platform @factory/cli-* packages share one version, so one
# package's `latest` dist-tag versions them all.
latest=$(au_http_get "https://registry.npmjs.org/@factory%2fcli-darwin-arm64" \
           | jq -r '."dist-tags".latest // ""')

assets=()
for pkg in cli-darwin-arm64 cli-darwin-x64-baseline cli-linux-arm64 cli-linux-x64-baseline; do
  assets+=(--asset "https://registry.npmjs.org/@factory/${pkg}/-/${pkg}-${latest}.tgz" "$pkg")
done

au_bump_release --name droid --file pkgs/droid.nix --version "$latest" \
  --attr .#martin.droid "${assets[@]}"
