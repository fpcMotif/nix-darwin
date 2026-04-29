#!/usr/bin/env bash
# Bump Factory AI's droid CLI by polling the npm registry for the
# @factory/cli-darwin-arm64 package version, then refreshing per-platform
# tarball hashes in pkgs/droid.nix.
#
# Why npm: Factory's downloads CDN (downloads.factory.ai) is reachable but
# not stable across CI; the npm registry mirrors every release as
# @factory/cli-${PLATFORM} tarballs with a single Bun-compiled binary at
# package/bin/droid.
set -euo pipefail
IFS=$'\n\t'

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/droid.nix"
FAKE='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

latest=$(curl -fsSL https://registry.npmjs.org/@factory/cli-darwin-arm64/latest \
  | jq -r '.version // ""')
[ -n "$latest" ] || { echo "could not fetch @factory/cli-darwin-arm64 latest" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "droid already at $latest"
  exit 0
fi

echo "droid: $current -> $latest"

sed -i.bak \
  -e "s|version = \"[^\"]*\"|version = \"${latest}\"|" \
  -e "s|hash = \"sha256-[^\"]*\"|hash = \"${FAKE}\"|g" \
  "$FILE"

platforms=$(grep -oE '"(aarch64-darwin|x86_64-darwin|aarch64-linux|x86_64-linux)" = ' "$FILE" \
  | grep -oE '"[^"]+"' | tr -d '"' | sort -u)

platform_url() {
  local platform="$1"
  awk -v plat="$platform" '
    $0 ~ "\\\"" plat "\\\" = " { in_block = 1 }
    in_block && match($0, /url = "[^"]+";/) {
      line = substr($0, RSTART, RLENGTH)
      sub(/^url = "/, "", line)
      sub(/";$/, "", line)
      print line
      exit
    }
  ' "$FILE"
}

replace_platform_hash() {
  local platform="$1"
  local hash="$2"
  local tmp

  tmp=$(mktemp "${FILE}.XXXXXX")
  awk -v plat="$platform" -v fake="$FAKE" -v real="$hash" '
    $0 ~ "\\\"" plat "\\\" = " { in_block = 1 }
    in_block && index($0, fake) {
      sub(fake, real)
      in_block = 0
    }
    { print }
  ' "$FILE" > "$tmp"
  mv "$tmp" "$FILE"
}

for platform in $platforms; do
  url=$(platform_url "$platform")
  [ -n "$url" ] || { echo "no URL found for droid $platform" >&2; exit 1; }
  url="${url//\$\{version\}/$latest}"
  hash=$(nix store prefetch-file --json "$url" | jq -r '.hash // ""')
  [ -n "$hash" ] || { echo "no hash discovered for droid $platform" >&2; exit 1; }
  replace_platform_hash "$platform" "$hash"
done

if grep -q "$FAKE" "$FILE"; then
  echo "one or more droid hashes are still fake" >&2
  exit 1
fi

nix build .#martin.droid --no-link
rm -f "$FILE.bak"
echo "droid bumped to $latest"
