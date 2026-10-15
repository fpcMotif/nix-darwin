#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

# Without a hold, the nightly re-pins a release known to break this packaging.
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
