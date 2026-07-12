#!/usr/bin/env bash
# Git merge driver for auto-updated pkgs/*.nix (mapped in .gitattributes as
# `merge=pkgnix`; registered in .git/config and modules/home/git.nix).
#
# scripts/update-*.sh run locally and the nightly auto-update PR rewrite the
# same `version = "..."` / `hash = "sha256-..."` lines, so a pull --rebase
# --autostash over local bumps conflicts on those lines, and rerere never
# helps because the literal strings differ every time.
#
# Whenever the two sides diverge ONLY in version/hash/url/rev assignment
# lines, take the newer-version side wholesale — each side is an internally
# consistent version+hash pair, so mixing lines across sides would pin the
# wrong hash. That mixing can happen even WITHOUT a textual conflict (upstream
# rotates only the hash while a local edit bumps only the version, on
# different lines: git unions them cleanly into a pairing that existed in
# neither side), so the churn check runs before any clean merge is accepted.
# Build metadata after `+` is ignored (semver precedence: bun canary builds
# share one semver); ties keep "ours", which during rebase/stash-apply is the
# freshly pulled upstream whose hashes CI already verified. Structural
# differences keep stock git behavior: clean unions are accepted, real
# conflicts get normal markers, which `just switch` refuses to build.
# Limitation: a side that is itself mispaired (version hand-bumped, hash not
# yet re-prefetched) is trusted as-is; the updater scripts self-heal that.

set -euo pipefail

base=$1 ours=$2 theirs=$3 marker=${4:-7} path=${5:-unknown-file}

# git rebase --autostash swallows the driver's stderr, so prefer the terminal
# for the audit note and fall back to stderr for non-interactive callers.
note() {
  { echo "pkgnix: $*" >/dev/tty; } 2>/dev/null || echo "pkgnix: $*" >&2
}

merged=$(mktemp) sides_diff=$(mktemp)
trap 'rm -f "$merged" "$sides_diff"' EXIT

clean=0
if git merge-file --marker-size="$marker" -p "$ours" "$base" "$theirs" >"$merged"; then
  clean=1
fi

# A result identical to one side cannot mispair fields — accept it.
if [ "$clean" -eq 1 ] && { cmp -s "$merged" "$ours" || cmp -s "$merged" "$theirs"; }; then
  cat "$merged" >"$ours"
  exit 0
fi

# Assignment lines whose churn is safe to side-pick: version/url/rev/tag/hash
# keys, or any `key = "sha256-..."` line (per-platform hash attrsets).
allowed='^([[:space:]]*(version|url|rev|tag|hash|sha256|[A-Za-z0-9_-]*Hash)[[:space:]]*=[[:space:]]*"[^"]*";?,?|[[:space:]]*"?[A-Za-z0-9_.-]+"?[[:space:]]*=[[:space:]]*"sha(256|512)-[^"]*";?,?)$'

diff "$ours" "$theirs" >"$sides_diff" || true
if sed -nE 's/^[<>] //p' "$sides_diff" | grep -qvE "$allowed"; then
  if [ "$clean" -eq 1 ]; then
    # Sides differ structurally but merge cleanly — stock git union.
    cat "$merged" >"$ours"
    exit 0
  fi
  git merge-file --marker-size="$marker" "$ours" "$base" "$theirs" || true
  note "$path has non-version/hash conflicts; left markers for manual resolution"
  exit 1
fi

pick_version() {
  sed -nE 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$1" | head -n1
}
ov=$(pick_version "$ours")
tv=$(pick_version "$theirs")

if [ -z "$ov" ] || [ -z "$tv" ]; then
  if [ "$clean" -eq 1 ]; then
    cat "$merged" >"$ours"
    exit 0
  fi
  git merge-file --marker-size="$marker" "$ours" "$base" "$theirs" || true
  note "$path missing a version literal; left markers for manual resolution"
  exit 1
fi

ovc=${ov%%+*} tvc=${tv%%+*}
if [ "$ovc" != "$tvc" ] && [ "$(printf '%s\n%s\n' "$ovc" "$tvc" | sort -V | tail -n1)" = "$tvc" ]; then
  cat "$theirs" >"$ours"
  note "$path auto-resolved to version $tv (dropped $ov)"
else
  note "$path auto-resolved to version $ov (dropped $tv)"
fi
exit 0
