#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/sf-mono.nix"
URL="https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg"

# Apple republishes the font at one unversioned URL, so only the hash shows a
# new release. A stale hash fails the whole `darwin-rebuild switch`.
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

au_build_darwin .#legacyPackages.aarch64-darwin.martin.sf-mono
au_report_change sf-mono "$current_hash" "$new_hash"
