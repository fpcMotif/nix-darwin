#!/usr/bin/env bash
# Bump badlogic/pi-mono prebuilt binary in pkgs/pi-coding-agent.nix.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/pi-coding-agent.nix"

latest=$(curl -fsSL https://api.github.com/repos/badlogic/pi-mono/releases/latest \
  | jq -r '.tag_name // ""' | sed 's/^v//')
[ -n "$latest" ] || { echo "could not detect latest pi-mono release" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "pi-coding-agent already at $latest"; exit 0
fi

url="https://github.com/badlogic/pi-mono/releases/download/v${latest}/pi-darwin-arm64.tar.gz"
nar=$(nix-prefetch-url "$url")
sri=$(nix hash convert --to sri --hash-algo sha256 "$nar")

sed -i.bak \
  -e "s|version = \"[^\"]*\"|version = \"${latest}\"|" \
  -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|" \
  "$FILE"

nix build .#martin.pi-coding-agent --no-link
rm -f "$FILE.bak"
echo "pi-coding-agent bumped to $latest"
