#!/usr/bin/env bash
# Bump can1357/oh-my-pi prebuilt binary in pkgs/oh-my-pi.nix.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/oh-my-pi.nix"

latest=$(curl -fsSL https://api.github.com/repos/can1357/oh-my-pi/releases/latest \
  | jq -r '.tag_name // ""' | sed 's/^v//')
[ -n "$latest" ] || { echo "could not detect latest oh-my-pi release" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "oh-my-pi already at $latest"; exit 0
fi

url="https://github.com/can1357/oh-my-pi/releases/download/v${latest}/omp-darwin-arm64.tar.gz"
nar=$(nix-prefetch-url "$url")
sri=$(nix hash convert --to sri --hash-algo sha256 "$nar")

sed -i.bak \
  -e "s|version = \"[^\"]*\"|version = \"${latest}\"|" \
  -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|" \
  "$FILE"

nix build .#martin.oh-my-pi --no-link
rm -f "$FILE.bak"
echo "oh-my-pi bumped to $latest"
