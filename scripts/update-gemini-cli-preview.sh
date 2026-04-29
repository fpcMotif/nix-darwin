#!/usr/bin/env bash
# Bump @google/gemini-cli @preview in pkgs/gemini-cli-preview.nix.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/gemini-cli-preview.nix"
FAKE='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

latest=$(curl -fsSL https://registry.npmjs.org/@google/gemini-cli \
  | jq -r '."dist-tags".preview // ""')
[ -n "$latest" ] || { echo "could not fetch @google/gemini-cli preview tag" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "gemini-cli-preview already at $latest"; exit 0
fi

sed -i.bak \
  -e "s|version = \"[^\"]*\"|version = \"${latest}\"|" \
  -e "s|hash = \"sha256-[^\"]*\"|hash = \"${FAKE}\"|" \
  -e "s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"${FAKE}\"|" \
  "$FILE"

discover() {
  set +e
  log=$(nix build .#martin.gemini-cli-preview --no-link 2>&1)
  set -e
  echo "$log" | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' \
    | head -1 | sed -E 's/got:[[:space:]]+//'
}

src_hash=$(discover)
[ -n "$src_hash" ] || { echo "no src hash extracted" >&2; exit 1; }
sed -i.bak2 "0,/hash = \"${FAKE}\"/{s|hash = \"${FAKE}\"|hash = \"${src_hash}\"|}" "$FILE"

npm_hash=$(discover)
[ -n "$npm_hash" ] || { echo "no npmDepsHash extracted" >&2; exit 1; }
sed -i.bak3 "s|npmDepsHash = \"${FAKE}\"|npmDepsHash = \"${npm_hash}\"|" "$FILE"

nix build .#martin.gemini-cli-preview --no-link
rm -f "$FILE.bak" "$FILE.bak2" "$FILE.bak3"
echo "gemini-cli-preview bumped to $latest"
