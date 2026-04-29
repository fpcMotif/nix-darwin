#!/usr/bin/env bash
# Bump @sourcegraph/amp in pkgs/sourcegraph-amp.nix and pkgs/sourcegraph-amp/.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/sourcegraph-amp.nix"
PKG_DIR="pkgs/sourcegraph-amp"
FAKE='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

latest=$(curl -fsSL 'https://registry.npmjs.org/@sourcegraph%2famp/latest' \
  | jq -r '.version // ""')
[ -n "$latest" ] || { echo "could not fetch @sourcegraph/amp version" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "sourcegraph-amp already at $latest"; exit 0
fi

# Update the dependency pin in package.json.
tmp=$(mktemp)
jq --arg v "$latest" '.dependencies."@sourcegraph/amp" = $v' "$PKG_DIR/package.json" > "$tmp"
mv "$tmp" "$PKG_DIR/package.json"

# Regenerate package-lock.json (offline-friendly, no install).
(cd "$PKG_DIR" && rm -f package-lock.json && npm install --package-lock-only --omit=peer)

# Patch nix file: version + fake npmDepsHash.
sed -i.bak \
  -e "s|version = \"[^\"]*\"|version = \"${latest}\"|" \
  -e "s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"${FAKE}\"|" \
  "$FILE"

set +e
log=$(nix build .#martin.sourcegraph-amp --no-link 2>&1)
set -e
npm_hash=$(echo "$log" | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' \
  | head -1 | sed -E 's/got:[[:space:]]+//')
[ -n "$npm_hash" ] || { echo "no npmDepsHash extracted" >&2; echo "$log" >&2; exit 1; }
sed -i.bak2 "s|npmDepsHash = \"${FAKE}\"|npmDepsHash = \"${npm_hash}\"|" "$FILE"

nix build .#martin.sourcegraph-amp --no-link
rm -f "$FILE.bak" "$FILE.bak2"
echo "sourcegraph-amp bumped to $latest"
