#!/usr/bin/env bash
# Bump nubjs/nub prebuilt binary in pkgs/nub.nix.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release nubjs/nub)

au_bump_release --name nub --file pkgs/nub.nix --version "$latest" \
  --attr .#martin.nub \
  --asset "https://github.com/nubjs/nub/releases/download/v${latest}/nub-darwin-arm64.tar.gz" 'releases/download'
