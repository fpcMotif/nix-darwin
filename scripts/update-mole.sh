#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

# Mole tags use a capital `V` prefix (V1.39.0).
latest=$(au_latest_github_release tw93/Mole '^V')
repo_url="https://github.com/tw93/Mole"

# The src anchor stops before the URL's literal `${version}`, which no anchor
# can match (see au_set_block_hash).
au_bump_release --name mole --file pkgs/mole.nix --version "$latest" \
  --attr .#martin.mole \
  --unpacked-asset "${repo_url}/archive/refs/tags/V${latest}.tar.gz" 'archive/refs/tags' \
  --asset "${repo_url}/releases/download/V${latest}/analyze-darwin-arm64" '/analyze-darwin-arm64' \
  --asset "${repo_url}/releases/download/V${latest}/status-darwin-arm64" '/status-darwin-arm64'
