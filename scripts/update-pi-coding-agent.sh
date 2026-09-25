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

HOLD_VERSIONS=()

latest=$(au_latest_github_release badlogic/pi-mono)
for held in "${HOLD_VERSIONS[@]}"; do
  if [ "$latest" = "$held" ]; then
    echo "pi-coding-agent: skipping held version $held (see HOLD_VERSIONS in $0)"
    exit 0
  fi
done

au_bump_release --name pi-coding-agent --file pkgs/pi-coding-agent.nix --version "$latest" \
  --attr .#martin.pi-coding-agent \
  --asset "https://github.com/badlogic/pi-mono/releases/download/v${latest}/pi-darwin-arm64.tar.gz" '/pi-darwin-arm64.tar.gz"'
