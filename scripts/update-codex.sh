#!/usr/bin/env bash
# Bump OpenAI Codex release binaries in pkgs/codex.nix.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/codex.nix"

latest=$(au_latest_github_release openai/codex '^rust-v')
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "codex already at $latest"; exit 0
fi
echo "codex: $current -> $latest"

au_set_version "$FILE" "$latest"

for asset in \
  codex-aarch64-apple-darwin \
  codex-x86_64-apple-darwin \
  codex-aarch64-unknown-linux-musl \
  codex-x86_64-unknown-linux-musl
do
  url="https://github.com/openai/codex/releases/download/rust-v${latest}/${asset}.tar.gz"
  au_set_block_hash "$FILE" "asset = \"${asset}\";" "$(au_prefetch_sri "$url")"
done

echo "codex bumped to $latest"
