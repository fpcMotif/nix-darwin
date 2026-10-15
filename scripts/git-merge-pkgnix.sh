#!/usr/bin/env bash
set -euo pipefail

# Local scripts/update-*.sh runs and the nightly auto-update PR rewrite the same version and hash
# lines. rerere cannot replay those conflicts because the strings differ each time.
base=$1 ours=$2 theirs=$3 marker=${4:-7} path=${5:-unknown-file}

# git rebase --autostash swallows a merge driver's stderr.
note() {
  { echo "pkgnix: $*" >/dev/tty; } 2>/dev/null || echo "pkgnix: $*" >&2
}

merged=$(mktemp) sides_diff=$(mktemp)
trap 'rm -f "$merged" "$sides_diff"' EXIT

exit_with_clean_merge() {
  cat "$merged" >"$ours"
  exit 0
}

exit_with_conflict_markers() {
  git merge-file --marker-size="$marker" "$ours" "$base" "$theirs" || true
  note "$path $1; left markers for manual resolution"
  exit 1
}

# Each side holds a consistent version and hash pair. Mixing lines across sides pins the wrong hash.
# Git mixes them without a conflict when an upstream hash-only change meets a local version-only bump.
clean=0
if git merge-file --marker-size="$marker" -p "$ours" "$base" "$theirs" >"$merged"; then
  clean=1
fi

# A result identical to one side cannot mispair fields.
if [ "$clean" -eq 1 ] && { cmp -s "$merged" "$ours" || cmp -s "$merged" "$theirs"; }; then
  exit_with_clean_merge
fi

# Per-platform hash attrsets key each hash by platform name, not by a hash-like key.
side_pickable_line='^([[:space:]]*(version|url|rev|tag|hash|sha256|[A-Za-z0-9_-]*Hash)[[:space:]]*=[[:space:]]*"[^"]*";?,?|[[:space:]]*"?[A-Za-z0-9_.-]+"?[[:space:]]*=[[:space:]]*"sha(256|512)-[^"]*";?,?)$'

# Leaving markers is safe because `just switch` refuses to build them.
diff "$ours" "$theirs" >"$sides_diff" || true
if sed -nE 's/^[<>] //p' "$sides_diff" | grep -qvE "$side_pickable_line"; then
  if [ "$clean" -eq 1 ]; then exit_with_clean_merge; fi
  exit_with_conflict_markers "has non-version/hash conflicts"
fi

first_version_literal() {
  sed -nE 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$1" | head -n1
}
ours_version=$(first_version_literal "$ours")
theirs_version=$(first_version_literal "$theirs")

if [ -z "$ours_version" ] || [ -z "$theirs_version" ]; then
  if [ "$clean" -eq 1 ]; then exit_with_clean_merge; fi
  exit_with_conflict_markers "missing a version literal"
fi

# Zed nightly builds share one semver, so build metadata after `+` is ignored.
# A tie keeps "ours", which during rebase or stash apply is the CI-verified upstream.
# A side that is itself mispaired is trusted. The updater scripts re-prefetch its hash.
ours_semver=${ours_version%%+*} theirs_semver=${theirs_version%%+*}
newer_semver=$(printf '%s\n%s\n' "$ours_semver" "$theirs_semver" | sort -V | tail -n1)
if [ "$ours_semver" != "$theirs_semver" ] && [ "$newer_semver" = "$theirs_semver" ]; then
  cat "$theirs" >"$ours"
  note "$path auto-resolved to version $theirs_version (dropped $ours_version)"
else
  note "$path auto-resolved to version $ours_version (dropped $theirs_version)"
fi
exit 0
