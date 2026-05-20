#!/usr/bin/env bash
# Bump opencode CLI + Electron desktop in lockstep. Both pkgs/opencode.nix
# and pkgs/opencode-electron.nix track the same upstream `sst/opencode`
# release.
#
# Hashes are computed via `nix-prefetch-url` per platform asset (works on
# any host OS), so the lockfile is never left with stub hashes after a
# partial update.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE_CLI="pkgs/opencode.nix"
FILE_ELECTRON="pkgs/opencode-electron.nix"

latest=$(au_latest_github_release sst/opencode)
current=$(au_current_version "$FILE_CLI")
if [ "$current" = "$latest" ]; then
  echo "opencode already at $latest"; exit 0
fi
echo "opencode: $current -> $latest"

au_set_version "$FILE_CLI" "$latest"
au_set_version "$FILE_ELECTRON" "$latest"

declare -A cli_assets=(
  [opencode-darwin-arm64.zip]=aarch64-darwin
  [opencode-linux-x64.tar.gz]=x86_64-linux
  [opencode-linux-arm64.tar.gz]=aarch64-linux
)
declare -A electron_assets=(
  # Upstream renamed `opencode-electron-*` → `opencode-desktop-*` in v1.15.x.
  [opencode-desktop-mac-arm64.zip]=aarch64-darwin
)

for asset in "${!cli_assets[@]}"; do
  url="https://github.com/sst/opencode/releases/download/v${latest}/${asset}"
  echo "  cli: $asset"
  # Anchor on the URL substring so platform blocks never collide.
  au_set_block_hash "$FILE_CLI" "/${asset}\"" "$(au_prefetch_sri "$url")"
done

for asset in "${!electron_assets[@]}"; do
  url="https://github.com/sst/opencode/releases/download/v${latest}/${asset}"
  echo "  electron: $asset"
  au_set_block_hash "$FILE_ELECTRON" "/${asset}\"" "$(au_prefetch_sri "$url")"
done

au_build .#martin.opencode
au_build .#martin.opencode-electron
echo "opencode bumped to $latest"
