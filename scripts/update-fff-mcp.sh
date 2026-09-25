#!/usr/bin/env bash
# Bump fff-mcp's versioned platform assets.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release dmtrKovalenko/fff)
base="https://github.com/dmtrKovalenko/fff/releases/download/v${latest}"

assets=()
for asset in \
  fff-mcp-aarch64-apple-darwin \
  fff-mcp-x86_64-apple-darwin \
  fff-mcp-aarch64-unknown-linux-gnu \
  fff-mcp-x86_64-unknown-linux-gnu
do
  assets+=(--asset "${base}/${asset}" "asset = \"${asset}\";")
done

au_bump_release --name fff-mcp --file pkgs/fff-mcp.nix --version "$latest" \
  --attr .#martin.fff-mcp "${assets[@]}"
