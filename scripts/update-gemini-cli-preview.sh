#!/usr/bin/env bash
# Bump @google/gemini-cli @preview in pkgs/gemini-cli-preview.nix.
#
# Both hashes are computed up-front:
#   - `src` hash: via `nix-prefetch-url --unpack` on the GitHub source tarball
#     (matches `fetchFromGitHub` semantics, which hashes the unpacked tree).
#   - `npmDepsHash`: via `prefetch-npm-deps` on the upstream package-lock.json
#     extracted from the same tarball. No fake-hash dance.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/gemini-cli-preview.nix"

latest=$(au_latest_npm "@google/gemini-cli" preview)
current=$(au_current_version "$FILE")
if [ "$current" = "$latest" ]; then
  echo "gemini-cli-preview already at $latest"; exit 0
fi
echo "gemini-cli-preview: $current -> $latest"

src_url="https://github.com/google-gemini/gemini-cli/archive/refs/tags/v${latest}.tar.gz"
src_hash=$(au_prefetch_unpacked_sri "$src_url")

# Pull just the package-lock.json from the upstream tag for npmDepsHash.
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
curl -fsSL "$src_url" | tar -xz -C "$work"
inner=$(find "$work" -maxdepth 1 -mindepth 1 -type d | head -1)
npm_hash=$(au_prefetch_npm_deps "$inner")

au_set_version "$FILE" "$latest"
au_set_block_hash "$FILE" 'tag = "v${finalAttrs.version}"' "$src_hash"
au_set_npm_deps_hash "$FILE" "$npm_hash"

au_build .#martin.gemini-cli-preview
echo "gemini-cli-preview bumped to $latest"
