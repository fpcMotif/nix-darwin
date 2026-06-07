#!/usr/bin/env bash
# Bump Google Drive for desktop in pkgs/google-drive.nix.
#
# Google serves the installer from a rolling, unversioned .dmg URL. The pin is
# therefore HASH-driven: re-prefetch the URL, diff the sha256 against the
# current derivation, and only rewrite when the bytes moved.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/google-drive.nix"
URL="https://dl.google.com/drive-file-stream/GoogleDrive.dmg"

new_hash=$(au_prefetch_sri "$URL")
case "$new_hash" in
  sha256-?*) ;;
  *) echo "google-drive: invalid SRI hash: '$new_hash'" >&2; exit 1 ;;
esac

current_hash=$(grep -oE 'hash = "sha256-[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
if [ "$new_hash" = "$current_hash" ]; then
  echo "google-drive already at $current_hash"; exit 0
fi

echo "google-drive: $current_hash -> $new_hash"
au_inplace_sed "$FILE" -e "s|hash = \"sha256-[^\"]*\"|hash = \"${new_hash}\"|"

# Linux auto-update runners can prefetch and rewrite the hash, but cannot build
# the darwin app. That failure is tolerated by auto-update.yml; build.yml does
# the real macOS validation on the generated PR.
au_build .#legacyPackages.aarch64-darwin.martin.google-drive
echo "google-drive bumped to $new_hash"
