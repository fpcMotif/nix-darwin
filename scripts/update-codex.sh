#!/usr/bin/env bash
# Bump OpenAI Codex release binaries in pkgs/codex.nix.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/codex.nix"

latest=$(curl -fsSL https://api.github.com/repos/openai/codex/releases/latest \
  | jq -r '.tag_name' | sed 's/^rust-v//')
[ -n "$latest" ] && [ "$latest" != "null" ] || {
  echo "could not detect latest codex release" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "codex already at $latest"
  exit 0
fi

prefetch_sri() {
  local asset=$1
  local url="https://github.com/openai/codex/releases/download/rust-v${latest}/${asset}.tar.gz"
  local nar
  nar=$(nix-prefetch-url "$url")
  nix hash convert --to sri --hash-algo sha256 "$nar"
}

replace_hash() {
  local asset=$1
  local hash=$2
  perl -0pi -e 's|(asset = "\Q'"$asset"'\E";\s+hash = ")[^"]+(")|$1'"$hash"'$2|s' "$FILE"
}

perl -0pi -e 's|version = "[^"]+"|version = "'"$latest"'"|' "$FILE"

for asset in \
  codex-aarch64-apple-darwin \
  codex-x86_64-apple-darwin \
  codex-aarch64-unknown-linux-musl \
  codex-x86_64-unknown-linux-musl
do
  replace_hash "$asset" "$(prefetch_sri "$asset")"
done

echo "codex bumped to $latest"
