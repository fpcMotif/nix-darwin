#!/usr/bin/env bash
set -euo pipefail

pkgs_dir=$1
scripts_dir=$2

# A republish at a URL without ${version} leaves a stale fixed-output hash that
# fails `just switch`. Only a re-prefetch recovers, so each rolling pin needs a
# hash-driven updater.
rolling_pins='sf-mono.nix update-sf-mono.sh'

updater_for() {
  local pin updater
  while read -r pin updater; do
    if [ "$pin" = "$1" ]; then
      echo "$updater"
    fi
  done <<<"$rolling_pins"
}

# A URL that interpolates a version is immutable per release.
unversioned_urls() {
  grep -oE 'url = "https://[^"]*"' "$1" 2>/dev/null | grep -v '\${' || true
}

fail=0

for f in "$pkgs_dir"/*.nix; do
  base=$(basename "$f")
  mutable=$(unversioned_urls "$f")
  [ -n "$mutable" ] || continue

  updater=$(updater_for "$base")
  if [ -z "$updater" ]; then
    echo "rolling-pins: ${base} pins a rolling (unversioned) URL but is not declared:" >&2
    printf '  %s\n' "$mutable" >&2
    echo "  Upstream republishing at that URL will break the whole switch with a" >&2
    echo "  fixed-output hash mismatch. Add a hash-driven scripts/update-*.sh and" >&2
    echo "  declare it in rolling_pins in tests/unit/rolling-pins-test.sh." >&2
    fail=1
    continue
  fi

  if [ ! -f "$scripts_dir/$updater" ]; then
    echo "rolling-pins: ${base} is declared rolling but ${updater} is missing" >&2
    fail=1
    continue
  fi

  # A version-driven updater cannot detect bytes moving under a fixed URL.
  if ! grep -qE 'au_prefetch_sri' "$scripts_dir/$updater"; then
    echo "rolling-pins: ${updater} must be hash-driven (au_prefetch_sri*) to" >&2
    echo "  recover ${base} from a rolling-asset republish" >&2
    fail=1
  fi
done

# A package that moves to a versioned URL leaves a stale rolling_pins entry.
while read -r base _; do
  if [ ! -f "$pkgs_dir/$base" ]; then
    echo "rolling-pins: declared ${base} no longer exists" >&2
    fail=1
  elif [ -z "$(unversioned_urls "$pkgs_dir/$base")" ]; then
    echo "rolling-pins: declared ${base} no longer pins an unversioned URL;" >&2
    echo "  drop it from rolling_pins" >&2
    fail=1
  fi
done <<<"$rolling_pins"

[ "$fail" -eq 0 ] || exit 1
echo "rolling-pins: every rolling pin has a hash-driven updater"
