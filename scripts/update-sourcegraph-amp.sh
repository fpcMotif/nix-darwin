#!/usr/bin/env bash
# Bump @sourcegraph/amp in pkgs/sourcegraph-amp.nix and pkgs/sourcegraph-amp/.
#
# Strategy: bump package.json, regenerate package-lock.json, bump the `version`
# line in the .nix file. No npmDepsHash to manage — `importNpmLock` derives the
# fixed-output deps from the lockfile at eval time.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/sourcegraph-amp.nix"
PKG_DIR="pkgs/sourcegraph-amp"

latest=$(au_latest_npm "@sourcegraph/amp")
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "sourcegraph-amp already at $latest"; exit 0
fi
echo "sourcegraph-amp: $current -> $latest"

# Update the package.json pin and regenerate the lockfile.
tmp=$(mktemp)
jq --arg v "$latest" '.dependencies."@sourcegraph/amp" = $v' \
  "$PKG_DIR/package.json" > "$tmp"
mv "$tmp" "$PKG_DIR/package.json"
(cd "$PKG_DIR" && rm -f package-lock.json \
   && npm install --package-lock-only --omit=peer >/dev/null)

au_set_version "$FILE" "$latest"

au_build .#martin.sourcegraph-amp
echo "sourcegraph-amp bumped to $latest"
