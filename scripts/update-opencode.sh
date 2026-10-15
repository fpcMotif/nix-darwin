#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release sst/opencode)
base="https://github.com/sst/opencode/releases/download/v${latest}"

# An anchor shared by every platform, such as the release URL, would match
# only the first platform block.
au_bump_release --name opencode --file pkgs/opencode.nix --version "$latest" \
  --attr .#martin.opencode \
  --asset "${base}/opencode-darwin-arm64.zip" '/opencode-darwin-arm64.zip"' \
  --asset "${base}/opencode-linux-x64.tar.gz" '/opencode-linux-x64.tar.gz"' \
  --asset "${base}/opencode-linux-arm64.tar.gz" '/opencode-linux-arm64.tar.gz"'
