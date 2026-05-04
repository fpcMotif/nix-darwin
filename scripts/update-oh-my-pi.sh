#!/usr/bin/env bash
# Bump can1357/oh-my-pi prebuilt binary in pkgs/oh-my-pi.nix.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/oh-my-pi.nix"

latest=$(au_latest_github_release can1357/oh-my-pi)
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "oh-my-pi already at $latest"; exit 0
fi
echo "oh-my-pi: $current -> $latest"

url="https://github.com/can1357/oh-my-pi/releases/download/v${latest}/omp-darwin-arm64"
sri=$(au_prefetch_sri "$url")

au_set_version "$FILE" "$latest"
au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|"

au_build .#martin.oh-my-pi
echo "oh-my-pi bumped to $latest"
