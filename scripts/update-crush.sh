#!/usr/bin/env bash
# Bump charmbracelet/crush in pkgs/default.nix (overlay override).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/default.nix"
RANGE_START='^  crush = _prev'
RANGE_END='^  });'
FAKE='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

latest=$(curl -fsSL https://api.github.com/repos/charmbracelet/crush/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//')
[ -n "$latest" ] && [ "$latest" != "null" ] || {
  echo "could not detect latest crush release" >&2; exit 1; }

current=$(awk "/${RANGE_START}/,/${RANGE_END}/" "$FILE" \
  | grep -oE 'version = "[^"]+"' | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "crush already at $latest"; exit 0
fi

# Patch version + fake the two hashes in the crush block.
sed -i.bak \
  -e "/${RANGE_START}/,/${RANGE_END}/ s|version = \"[^\"]*\"|version = \"${latest}\"|" \
  -e "/${RANGE_START}/,/${RANGE_END}/ s|hash = \"sha256-[^\"]*\"|hash = \"${FAKE}\"|" \
  -e "/${RANGE_START}/,/${RANGE_END}/ s|vendorHash = \"sha256-[^\"]*\"|vendorHash = \"${FAKE}\"|" \
  "$FILE"

discover() {
  set +e
  log=$(nix build .#crush --no-link 2>&1)
  set -e
  echo "$log" | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' \
    | head -1 | sed -E 's/got:[[:space:]]+//'
}

src_hash=$(discover)
[ -n "$src_hash" ] || { echo "no src hash extracted" >&2; exit 1; }
sed -i.bak2 "/${RANGE_START}/,/${RANGE_END}/ s|hash = \"${FAKE}\"|hash = \"${src_hash}\"|" "$FILE"

vendor_hash=$(discover)
[ -n "$vendor_hash" ] || { echo "no vendor hash extracted" >&2; exit 1; }
sed -i.bak3 "/${RANGE_START}/,/${RANGE_END}/ s|vendorHash = \"${FAKE}\"|vendorHash = \"${vendor_hash}\"|" "$FILE"

nix build .#crush --no-link
rm -f "$FILE.bak" "$FILE.bak2" "$FILE.bak3"
echo "crush bumped to $latest"
