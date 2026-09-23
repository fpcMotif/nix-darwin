#!/usr/bin/env bash
# Bump fff-mcp's versioned platform assets.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release dmtrKovalenko/fff)
base="https://github.com/dmtrKovalenko/fff/releases/download/v${latest}"

au_bump_release --name fff-mcp --file pkgs/fff-mcp.nix --version "$latest" \
  --attr .#martin.fff-mcp \
  --asset "${base}/fff-mcp-aarch64-apple-darwin" 'asset = "fff-mcp-aarch64-apple-darwin";' \
  --asset "${base}/fff-mcp-x86_64-apple-darwin" 'asset = "fff-mcp-x86_64-apple-darwin";' \
  --asset "${base}/fff-mcp-aarch64-unknown-linux-gnu" 'asset = "fff-mcp-aarch64-unknown-linux-gnu";' \
  --asset "${base}/fff-mcp-x86_64-unknown-linux-gnu" 'asset = "fff-mcp-x86_64-unknown-linux-gnu";'
