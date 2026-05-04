#!/usr/bin/env bash
# Bump opencode CLI + Electron desktop by polling sst/opencode GitHub
# releases. Both pkgs/opencode.nix and pkgs/opencode-electron.nix share the
# same upstream version; we update them in lockstep.
#
# Hashes are computed via `nix-prefetch-url` for every platform (works
# regardless of host OS), so the lockfile is never left with stub hashes
# after a partial update.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

FILE_CLI="pkgs/opencode.nix"
FILE_ELECTRON="pkgs/opencode-electron.nix"

latest=$(curl -fsSL https://api.github.com/repos/sst/opencode/releases/latest \
  | jq -r '.tag_name // ""' | sed 's/^v//')
[ -n "$latest" ] || { echo "could not fetch sst/opencode latest tag" >&2; exit 1; }

current=$(grep -oE 'version = "[^"]+"' "$FILE_CLI" | head -1 | cut -d'"' -f2)
if [ "$current" = "$latest" ]; then
  echo "opencode already at $latest"; exit 0
fi
echo "opencode: $current -> $latest"

prefetch_sri() {
  local url=$1
  local nar
  nar=$(nix-prefetch-url "$url")
  nix hash convert --to sri --hash-algo sha256 "$nar"
}

# Replace the hash whose enclosing source block matches the given asset
# basename. Each block is guarded by its `url = "...<asset>"` line so we never
# overwrite the wrong platform's hash.
replace_hash() {
  local file=$1
  local asset=$2
  local hash=$3
  perl -0pi -e 's|(/'"$asset"'";\s+hash = ")[^"]+(")|$1'"$hash"'$2|s' "$file"
}

# Bump the version literal in each file once.
for f in "$FILE_CLI" "$FILE_ELECTRON"; do
  perl -0pi -e 's|version = "[^"]+"|version = "'"$latest"'"|' "$f"
done

declare -A cli_assets=(
  ["opencode-darwin-arm64.zip"]="aarch64-darwin"
  ["opencode-linux-x64.tar.gz"]="x86_64-linux"
  ["opencode-linux-arm64.tar.gz"]="aarch64-linux"
)

declare -A electron_assets=(
  ["opencode-electron-mac-arm64.zip"]="aarch64-darwin"
)

for asset in "${!cli_assets[@]}"; do
  url="https://github.com/sst/opencode/releases/download/v${latest}/${asset}"
  echo "  cli: $asset"
  replace_hash "$FILE_CLI" "$asset" "$(prefetch_sri "$url")"
done

for asset in "${!electron_assets[@]}"; do
  url="https://github.com/sst/opencode/releases/download/v${latest}/${asset}"
  echo "  electron: $asset"
  replace_hash "$FILE_ELECTRON" "$asset" "$(prefetch_sri "$url")"
done

# Verify the native platform builds end-to-end.
nix build .#martin.opencode --no-link
nix build .#martin.opencode-electron --no-link

echo "opencode bumped to $latest"
