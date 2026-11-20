#!/usr/bin/env bash
set -euo pipefail

scripts_dir=$1
driver="$scripts_dir/git-merge-pkgnix.sh"

fail() { echo "git-merge-pkgnix-test: $*" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

pin() {
  printf '{\n  version = "%s";\n  hash = "sha256-%s=";\n}\n' "$1" "$2"
}

merge() {
  pin "$1" BASE >"$work/base"
  pin "$2" OURS >"$work/ours"
  pin "$3" THEIRS >"$work/theirs"
  bash "$driver" "$work/base" "$work/ours" "$work/theirs" 7 pkgs/sample.nix 2>/dev/null
}

expect_resolved() {
  local base=$1 ours=$2 theirs=$3 want_version=$4 want_hash=$5 label=$6
  merge "$base" "$ours" "$theirs" || fail "$label: driver left a conflict"
  grep -qF "version = \"$want_version\";" "$work/ours" \
    || fail "$label: expected version $want_version in $(cat "$work/ours")"
  grep -qF "sha256-${want_hash}=" "$work/ours" \
    || fail "$label: expected hash $want_hash in $(cat "$work/ours")"
}

expect_conflict() {
  local base=$1 ours=$2 theirs=$3 label=$4
  if merge "$base" "$ours" "$theirs"; then
    fail "$label: driver resolved an incomparable version"
  fi
  grep -qF '<<<<<<<' "$work/ours" || fail "$label: driver left no conflict markers"
}

expect_resolved 0.47.0 0.48.0 0.48.0-alpha.3 0.48.0 OURS "stable-vs-alpha"
expect_resolved 0.47.0 0.48.0-alpha.3 0.48.0 0.48.0 THEIRS "alpha-vs-stable"
expect_resolved 0.47.0 0.48.0 0.49.0 0.49.0 THEIRS "newer-stable"
expect_resolved 0.47.0 0.9.0 0.10.0 0.10.0 THEIRS "numeric-minor"
expect_resolved 0.180.0+nightly.1 0.181.0+nightly.10 0.181.0+nightly.20 0.181.0+nightly.10 OURS "build-metadata-tie"

expect_conflict 0.47.0 canary 0.48.0 "unparsable-ours"
expect_conflict 0.47.0 0.48.0 canary "unparsable-theirs"
expect_conflict 0.47.0 +nightly.1 0.48.0 "empty-semver-core"

echo "git-merge-pkgnix-test: all assertions passed"
