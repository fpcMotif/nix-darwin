#!/usr/bin/env bash
# Bump badlogic/pi-mono prebuilt binary in pkgs/pi-coding-agent.nix.
#
# HOLD_VERSIONS: versions known to be broken on our packaging style. The
# auto-updater skips them so a daily CI run can't reintroduce a fixed
# regression. Remove an entry once upstream's release tarball ships the
# missing piece.
#   (none currently held)
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/pi-coding-agent.nix"
HOLD_VERSIONS=()

latest=$(au_latest_github_release badlogic/pi-mono)
for held in "${HOLD_VERSIONS[@]}"; do
  if [ "$latest" = "$held" ]; then
    echo "pi-coding-agent: skipping held version $held (see HOLD_VERSIONS in $0)"
    exit 0
  fi
done

current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "pi-coding-agent already at $latest"; exit 0
fi
echo "pi-coding-agent: $current -> $latest"

url="https://github.com/badlogic/pi-mono/releases/download/v${latest}/pi-darwin-arm64.tar.gz"
sri=$(au_prefetch_sri "$url")

au_set_version "$FILE" "$latest"
au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${sri}\"|"

au_build .#martin.pi-coding-agent
echo "pi-coding-agent bumped to $latest"
