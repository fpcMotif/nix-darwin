#!/usr/bin/env bash
# Bump Factory AI's droid CLI by polling the npm registry for the
# @factory/cli-darwin-arm64 package version, then refreshing per-platform
# hashes in pkgs/droid.nix via the fake-hash dance.
#
# Why npm: Factory's downloads CDN (downloads.factory.ai) is reachable but
# not stable across CI; the npm registry mirrors every release as
# @factory/cli-${PLATFORM} tarballs with a single Bun-compiled binary at
# package/bin/droid.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE="pkgs/droid.nix"
FAKE='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

latest=$(curl -fsSL https://registry.npmjs.org/@factory/cli-darwin-arm64/latest \
  | jq -r '.version // ""')
[ -n "$latest" ] || { echo "could not fetch @factory/cli-darwin-arm64 latest" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "droid already at $latest"; exit 0
fi

echo "droid: $current -> $latest"

# Bump the version literal and stub every per-platform hash with FAKE.
sed -i.bak \
  -e "s|version = \"[^\"]*\"|version = \"${latest}\"|" \
  -e "s|hash = \"sha256-[^\"]*\"|hash = \"${FAKE}\"|g" \
  "$FILE"

# For each platform listed in droid.nix, do a single nix build pass and
# extract the reported hash from the failure trace, then patch one line.
plats=$(grep -oE '"(aarch64-darwin|x86_64-darwin|aarch64-linux|x86_64-linux)" = ' "$FILE" \
  | grep -oE '"[^"]+"' | tr -d '"' | sort -u)

for plat in $plats; do
  set +e
  log=$(nix build --impure \
    --expr "(builtins.getFlake (toString ./.)).inputs.nixpkgs.legacyPackages.${plat}.callPackage ./pkgs/droid.nix {}" \
    --no-link 2>&1)
  set -e
  got=$(printf '%s\n' "$log" | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' \
    | head -1 | sed -E 's/got:[[:space:]]+//')
  if [ -z "$got" ]; then
    echo "no hash for $plat (build may have succeeded; skipping):"
    printf '%s\n' "$log" | tail -5
    continue
  fi
  # Replace the FIRST remaining FAKE under this platform's block.
  awk -v plat="$plat" -v fake="$FAKE" -v real="$got" '
    $0 ~ "\"" plat "\" = " { in_block = 1 }
    in_block && index($0, fake) {
      sub(fake, real)
      in_block = 0
    }
    { print }
  ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
done

# Final native-platform validation.
nix build .#martin.droid --no-link
rm -f "$FILE.bak"
echo "droid bumped to $latest"
