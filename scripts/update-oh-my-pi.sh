#!/usr/bin/env bash
# Bump can1357/oh-my-pi prebuilt binary in pkgs/oh-my-pi.nix.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release can1357/oh-my-pi)

au_bump_release --name oh-my-pi --file pkgs/oh-my-pi.nix --version "$latest" \
  --attr .#martin.oh-my-pi \
  --asset "https://github.com/can1357/oh-my-pi/releases/download/v${latest}/omp-darwin-arm64" '/omp-darwin-arm64"'
