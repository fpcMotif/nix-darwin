#!/usr/bin/env bash
# Bump badlogic/pi-mono prebuilt binary in pkgs/pi-coding-agent.nix.
#
# Hold list: versions known to be broken on our pinning style. The auto-
# updater skips them so a daily CI run can't reintroduce a fixed regression.
# Remove an entry once upstream's release tarball ships the missing piece.
#   0.71.0 — `pi-npm-bun root -g` startup crash; tarball lacks pi-npm-bun
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/pi-coding-agent.nix"
# Empty hold list. If a future pi-mono release reintroduces a startup
# regression, append the bad version here so the auto-updater skips it
# until upstream patches the issue.
HOLD_VERSIONS=()

latest=$(curl -fsSL https://api.github.com/repos/badlogic/pi-mono/releases/latest \
  | jq -r '.tag_name // ""' | sed 's/^v//')
[ -n "$latest" ] || { echo "could not detect latest pi-mono release" >&2; exit 1; }

for held in "${HOLD_VERSIONS[@]}"; do
  if [ "$latest" = "$held" ]; then
    echo "pi-coding-agent: skipping held version $held (see HOLD_VERSIONS in $0)"
    exit 0
  fi
done

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
