#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release modem-dev/hunk)
asset="hunkdiff-darwin-arm64.tar.gz"

au_bump_release --name hunk --file pkgs/hunk-bin.nix --version "$latest" \
  --attr .#martin.hunk-bin \
  --asset "https://github.com/modem-dev/hunk/releases/download/v${latest}/${asset}" "/${asset}\""
