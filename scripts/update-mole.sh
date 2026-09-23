#!/usr/bin/env bash
# Bump tw93/Mole (mo / mole) in pkgs/mole.nix. Mole tags use a capital `V`
# prefix (V1.39.0), unlike the standard `v` lower-case convention.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

latest=$(au_latest_github_release tw93/Mole '^V')
base="https://github.com/tw93/Mole"

# src uses fetchzip → unpacked hash. Anchor on `archive/refs/tags` (unique to
# the source URL): the literal `${version}` in the URL must NOT appear in the
# anchor, because au_set_block_hash feeds it through Perl's \Q…\E, which first
# interpolates `$version` (empty) and so would never match.
au_bump_release --name mole --file pkgs/mole.nix --version "$latest" \
  --attr .#martin.mole \
  --unpacked-asset "${base}/archive/refs/tags/V${latest}.tar.gz" 'archive/refs/tags' \
  --asset "${base}/releases/download/V${latest}/analyze-darwin-arm64" '/analyze-darwin-arm64' \
  --asset "${base}/releases/download/V${latest}/status-darwin-arm64" '/status-darwin-arm64'
