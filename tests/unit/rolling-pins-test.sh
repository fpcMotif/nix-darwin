#!/usr/bin/env bash
set -euo pipefail

# Guards the class of failure that takes down `just switch` with
#
#   error: hash mismatch in fixed-output derivation '...bun-darwin-aarch64.zip.drv'
#
# A package whose download URL carries no ${version} is pinned to a *rolling*
# asset: upstream republishes different bytes at the same URL, the recorded
# sha256 goes stale, and the fixed-output derivation fails the entire system
# build — not just that package. The only recovery is re-prefetching the URL, so
# every rolling pin MUST own a hash-driven updater script. A rolling pin without
# one is a landmine that can only be defused by hand-editing a hash.
#
# Adding a new unversioned URL to pkgs/ therefore fails this test until it is
# declared below and given an updater.

pkgs_dir=$1
scripts_dir=$2

# file basename -> updater script basename
declared_rolling() {
  case "$1" in
    bun-canary-bin.nix) echo "update-bun-canary.sh" ;;
    google-drive.nix)   echo "update-google-drive.sh" ;;
    sf-mono.nix)        echo "update-sf-mono.sh" ;;
    *)                  echo "" ;;
  esac
}

fail=0

for f in "$pkgs_dir"/*.nix; do
  base=$(basename "$f")
  # URLs that interpolate a version are immutable per release — skip them.
  mutable=$(grep -oE 'url = "https://[^"]*"' "$f" 2>/dev/null \
              | grep -v '\${' || true)
  [ -n "$mutable" ] || continue

  updater=$(declared_rolling "$base")
  if [ -z "$updater" ]; then
    echo "rolling-pins: ${base} pins a rolling (unversioned) URL but is not declared:" >&2
    printf '  %s\n' "$mutable" >&2
    echo "  Upstream republishing at that URL will break the whole switch with a" >&2
    echo "  fixed-output hash mismatch. Add a hash-driven scripts/update-*.sh and" >&2
    echo "  declare it in declared_rolling() above." >&2
    fail=1
    continue
  fi

  if [ ! -f "$scripts_dir/$updater" ]; then
    echo "rolling-pins: ${base} is declared rolling but ${updater} is missing" >&2
    fail=1
    continue
  fi

  # The updater has to actually re-prefetch, not just bump a version string —
  # a version-driven updater cannot detect bytes moving under a fixed URL.
  if ! grep -qE 'au_prefetch_sri' "$scripts_dir/$updater"; then
    echo "rolling-pins: ${updater} must be hash-driven (au_prefetch_sri*) to" >&2
    echo "  recover ${base} from a rolling-asset republish" >&2
    fail=1
  fi
done

# Every declared entry must still correspond to a real rolling pin, so the list
# cannot rot into fiction after a package switches to a versioned URL.
for base in bun-canary-bin.nix google-drive.nix sf-mono.nix; do
  [ -f "$pkgs_dir/$base" ] || { echo "rolling-pins: declared ${base} no longer exists" >&2; fail=1; }
done

[ "$fail" -eq 0 ] || exit 1
echo "rolling-pins: every rolling pin has a hash-driven updater"
