#!/usr/bin/env bash
# Bump SF Mono in pkgs/sf-mono.nix.
#
# Apple serves the font from a rolling, unversioned .dmg URL, so the pinned
# sha256 goes stale the moment they republish — and a stale fixed-output hash
# fails the whole `darwin-rebuild switch`, not just this package. The pin is
# therefore HASH-driven, exactly like pkgs/google-drive.nix: re-prefetch the
# URL, diff the sha256 against the current derivation, rewrite only when the
# bytes actually moved.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/sf-mono.nix"
URL="https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg"

new_hash=$(au_prefetch_sri "$URL")
case "$new_hash" in
  sha256-?*) ;;
  *) echo "sf-mono: invalid SRI hash: '$new_hash'" >&2; exit 1 ;;
esac

current_hash=$(grep -oE 'hash = "sha256-[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$new_hash" = "$current_hash" ]; then
  echo "sf-mono already at $current_hash"; exit 0
fi

au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${new_hash}\"|"

# Linux runners can prefetch and rewrite the hash, then defer this Darwin build.
# build.yml performs the real macOS validation on the generated PR.
au_build_darwin .#legacyPackages.aarch64-darwin.martin.sf-mono
au_report_change sf-mono "$current_hash" "$new_hash"
