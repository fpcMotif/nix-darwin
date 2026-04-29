#!/usr/bin/env bash
# Bump starship-claude (starship/starship override) in pkgs/default.nix.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/default.nix"
RANGE_START='^    starship-claude = final.starship.overrideAttrs'
RANGE_END='^    });'
FAKE='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

latest=$(curl -fsSL https://api.github.com/repos/starship/starship/releases/latest \
  | jq -r '.tag_name // ""' | sed 's/^v//')
[ -n "$latest" ] || { echo "could not detect latest starship release" >&2; exit 1; }

current=$(awk "/${RANGE_START}/,/${RANGE_END}/" "$FILE" \
  | grep -oE 'version = "[^"]+"' | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "starship-claude already at $latest"; exit 0
fi

# Patch version + fake both hashes within the starship-claude block.
sed -i.bak \
  -e "/${RANGE_START}/,/${RANGE_END}/ s|version = \"[^\"]*\"|version = \"${latest}\"|" \
  -e "/${RANGE_START}/,/${RANGE_END}/ s|hash = \"sha256-[^\"]*\"|hash = \"${FAKE}\"|" \
  "$FILE"

discover() {
  set +e
  log=$(nix build .#martin.starship-claude --no-link 2>&1)
  set -e
  echo "$log" | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' \
    | head -1 | sed -E 's/got:[[:space:]]+//'
}

src_hash=$(discover)
[ -n "$src_hash" ] || { echo "no src hash extracted" >&2; exit 1; }
# Replace the FIRST occurrence (src) within the block, leave the second (cargoDeps) faked.
awk -v fake="$FAKE" -v real="$src_hash" -v rs="$RANGE_START" -v re="$RANGE_END" '
BEGIN { inblk = 0; replaced = 0 }
$0 ~ rs { inblk = 1 }
inblk && !replaced && index($0, "hash = \"" fake "\"") {
  sub("hash = \"" fake "\"", "hash = \"" real "\"")
  replaced = 1
}
$0 ~ re && inblk { inblk = 0 }
{ print }
' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

cargo_hash=$(discover)
[ -n "$cargo_hash" ] || { echo "no cargoDeps hash extracted" >&2; exit 1; }
sed -i.bak2 \
  "/${RANGE_START}/,/${RANGE_END}/ s|hash = \"${FAKE}\"|hash = \"${cargo_hash}\"|" \
  "$FILE"

nix build .#martin.starship-claude --no-link
rm -f "$FILE.bak" "$FILE.bak2"
echo "starship-claude bumped to $latest"
