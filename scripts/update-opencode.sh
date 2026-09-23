#!/usr/bin/env bash
# Bump opencode CLI in lockstep with the upstream `sst/opencode` release.
# Each platform asset's hash is anchored on its URL file name, so platform
# blocks never collide.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release sst/opencode)
base="https://github.com/sst/opencode/releases/download/v${latest}"

au_bump_release --name opencode --file pkgs/opencode.nix --version "$latest" \
  --attr .#martin.opencode \
  --asset "${base}/opencode-darwin-arm64.zip" '/opencode-darwin-arm64.zip"' \
  --asset "${base}/opencode-linux-x64.tar.gz" '/opencode-linux-x64.tar.gz"' \
  --asset "${base}/opencode-linux-arm64.tar.gz" '/opencode-linux-arm64.tar.gz"'
