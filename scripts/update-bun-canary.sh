#!/usr/bin/env bash
# Bump pkgs/bun-canary-bin.nix to the current bun `canary` release.
#
# bun force-pushes the `canary` git tag in place, so there is no per-build
# download URL — the pin is the rolling asset's sha256. Idempotency is
# therefore HASH-driven: re-prefetch the rolling zip, diff its sha256 against
# the pin, and only rewrite when the bytes moved.
#
# Version detection can't use npm (its `canary` dist-tag lagged weeks behind —
# read 1.3.13-canary while the tag served 1.4.0-canary) and can't run the
# darwin-aarch64 binary on the Linux CI runner, so the semver is parsed out of
# the binary's own bytes with `strings` (a byte scan, so cross-platform). An
# asset-date stamp is the fallback so an upstream format change can't blank the
# version pin.
#
# Platforms: aarch64-darwin only, matching pkgs/bun-canary-bin.nix and the
# flake's supportedSystems list.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

FILE="pkgs/bun-canary-bin.nix"
URL="https://github.com/oven-sh/bun/releases/download/canary/bun-darwin-aarch64.zip"

# One prefetch yields both the SRI hash and the on-disk zip we strings for the
# version. au_prefetch_sri_path emits the hash on line 1, store path on line 2.
prefetch=$(au_prefetch_sri_path "$URL")
{ IFS= read -r new_hash; IFS= read -r zip_path; } <<<"$prefetch"
case "$new_hash" in
  sha256-?*) ;;
  *) echo "bun-canary: invalid SRI hash: '$new_hash'" >&2; exit 1 ;;
esac

current_hash=$(grep -oE 'hash = "sha256-[^"]+"' "$FILE" | head -1 | cut -d'"' -f2)
current_ver=$(au_current_version "$FILE")
if [ "$new_hash" = "$current_hash" ]; then
  echo "bun-canary already at $current_ver"; exit 0
fi

# Version is informational (the hash above is what gates idempotency).
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
new_ver=""
if [ -n "$zip_path" ] && unzip -q -o "$zip_path" -d "$work" 2>/dev/null; then
  bin=$(find "$work" -maxdepth 2 -name bun -type f -print -quit)
  [ -n "$bin" ] && new_ver=$(strings -n 6 "$bin" 2>/dev/null \
    | grep -oE '1\.[0-9]+\.[0-9]+-canary\.[0-9]+\+[0-9a-f]{7,}' \
    | sort -u | head -1)
fi
if [ -z "$new_ver" ]; then
  asset_date=$(gh api repos/oven-sh/bun/releases/tags/canary \
                 --jq '.assets[]|select(.name=="bun-darwin-aarch64.zip").updated_at' \
                 2>/dev/null | cut -dT -f1)
  new_ver="canary-${asset_date:-unknown}"
fi

au_set_version "$FILE" "$new_ver"
au_set_block_hash "$FILE" '"aarch64-darwin"' "$new_hash"

# Cross-compiles nothing: Linux defers this Darwin build; build.yml validates
# it on macOS. Local Darwin runs build it here.
au_build_darwin .#legacyPackages.aarch64-darwin.martin.bun-canary-bin
au_report_change bun-canary "$current_ver" "$new_ver"
