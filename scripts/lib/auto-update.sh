# shellcheck shell=bash
# Shared helpers for scripts/update-*.sh.
#
# Source this from each updater:
#   . "$(dirname "$0")/lib/auto-update.sh"
#   cd "$(au_repo_root)"
#
# Design rules:
#   1. Never use `sed -i.bak` — it leaves stray .bak artifacts when a later
#      step fails. Use `au_inplace_sed` instead, which writes via mktemp.
#   2. Never commit FAKE placeholder hashes. Prefer prefetch helpers that
#      compute the real hash up-front. The fake-hash dance is the last
#      resort (vendorHash, cargoDeps where no direct prefetch exists).
#   3. Idempotent — every updater must early-exit when already at latest.
#   4. Treat any non-zero from the helpers as fatal; the workflow's
#      `au_assert_clean` guard at the end catches anything that slips by.

set -euo pipefail

# Resolve the repo root from the calling script's path (BASH_SOURCE[1]).
au_repo_root() {
  cd "$(dirname "${BASH_SOURCE[1]}")/.." > /dev/null && pwd
}

# ---------------------------------------------------------------------------
# Version polling
# ---------------------------------------------------------------------------

# Latest GitHub release tag (including pre-releases if they are the newest).
#   au_latest_github_release <owner/repo> [strip-regex]
au_latest_github_release() {
  local repo=$1 strip=${2:-^v}
  local v
  v=$(curl -fsSL "https://api.github.com/repos/${repo}/releases?per_page=1" \
        | jq -r '.[0].tag_name // ""' | sed "s|${strip}||")
  [ -n "$v" ] && [ "$v" != "null" ] || {
    echo "au_latest_github_release: empty tag for ${repo}" >&2; return 1
  }
  printf '%s\n' "$v"
}

# Latest npm version, prioritizing bleeding-edge tags (canary, dev, next, etc.)
# when 'latest' is requested.
#   au_latest_npm <pkg> [dist-tag]
au_latest_npm() {
  local pkg=$1 tag=${2:-latest}
  local encoded="${pkg//\//%2f}"
  local v
  if [ "$tag" = latest ]; then
    # Bleeding-edge priority: pick the first available tag.
    # We push iteration and filtering natively into jq to minimize subprocess overhead.
    v=$(curl -fsSL "https://registry.npmjs.org/${encoded}" | jq -r '
      (.["dist-tags"] // {}) as $tags |
      ["canary", "dev", "next", "preview", "beta", "alpha", "rc", "latest"] |
      map(select(. as $k | $tags[$k] and $tags[$k] != "" and $tags[$k] != null)) |
      first |
      if . then $tags[.] else "" end
    ')
  else
    v=$(curl -fsSL "https://registry.npmjs.org/${encoded}" \
          | jq -r --arg t "$tag" '."dist-tags"[$t] // ""')
  fi
  [ -n "$v" ] && [ "$v" != "null" ] || {
    echo "au_latest_npm: empty version for ${pkg}@${tag}" >&2; return 1
  }
  printf '%s\n' "$v"
}

# Read the first `version = "..."` literal in a file. Pass an awk address
# range (`/start/,/end/`) to scope to a nested block.
#   au_current_version <file> [awk-range]
au_current_version() {
  local file=$1 range=${2:-}
  if [ -n "$range" ]; then
    awk "$range" "$file" \
      | grep -oE 'version = "[^"]+"' | head -1 | cut -d'"' -f2
  else
    grep -oE 'version = "[^"]+"' "$file" | head -1 | cut -d'"' -f2
  fi
}

# ---------------------------------------------------------------------------
# Hash computation
# ---------------------------------------------------------------------------

# Compute SRI sha256 for a URL (works on any host platform).
au_prefetch_sri() {
  local url=$1
  local nar
  nar=$(nix-prefetch-url --quiet "$url")
  nix hash convert --to sri --hash-algo sha256 "$nar"
}

# Same, unpacking the tarball first. Use this when matching a `fetchFromGitHub`
# / `fetchzip` style hash (which hashes the unpacked tree, not the tarball).
au_prefetch_unpacked_sri() {
  local url=$1
  local nar
  nar=$(nix-prefetch-url --unpack --quiet "$url")
  nix hash convert --to sri --hash-algo sha256 "$nar"
}

# Compute npmDepsHash directly from a package-lock.json — no fake-hash dance.
#   au_prefetch_npm_deps <dir-containing-package-lock.json>
au_prefetch_npm_deps() {
  local lockdir=$1
  [ -f "$lockdir/package-lock.json" ] || {
    echo "au_prefetch_npm_deps: $lockdir/package-lock.json not found" >&2
    return 1
  }
  nix run --quiet nixpkgs#prefetch-npm-deps -- "$lockdir/package-lock.json"
}

# Last-resort fake-hash dance: stub the chosen attr with a placeholder, run
# the build, and parse the resulting `got: sha256-…` from the failure log.
# Use only for cargoDeps / vendorHash / npmDepsHash where no direct prefetch
# exists.
#
#   au_extract_got_hash <flake-attr>
AU_FAKE_HASH='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='
au_extract_got_hash() {
  local attr=$1
  local log
  set +e
  log=$(nix build "$attr" --no-link 2>&1)
  set -e
  local got
  got=$(printf '%s\n' "$log" | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' \
          | head -1 | sed -E 's/got:[[:space:]]+//')
  [ -n "$got" ] || {
    echo "au_extract_got_hash: no 'got: sha256-…' line in build output" >&2
    printf '%s\n' "$log" | tail -20 >&2
    return 1
  }
  printf '%s\n' "$got"
}

# ---------------------------------------------------------------------------
# In-place file edits (no .bak files left behind)
# ---------------------------------------------------------------------------

# Portable in-place sed across GNU/BSD via mktemp shuffle.
#   au_inplace_sed <file> -e 'expr1' [-e 'expr2' ...]
au_inplace_sed() {
  local file=$1; shift
  local tmp
  tmp=$(mktemp)
  sed "$@" "$file" > "$tmp" && mv "$tmp" "$file"
}

# Update the first `version = "..."` literal in a file. Optionally scoped to
# a sed address range like `/^starship-claude/,/^});/`.
#   au_set_version <file> <new-version> [sed-range]
au_set_version() {
  local file=$1 ver=$2 range=${3:-}
  local expr="s|version = \"[^\"]*\"|version = \"${ver}\"|"
  if [ -n "$range" ]; then expr="${range} ${expr}"; fi
  au_inplace_sed "$file" -e "$expr"
}

# Replace the `hash = "..."` line that follows an anchor (e.g. an attribute
# name like `"aarch64-darwin"` or a URL substring). The anchor and hash must
# live in the same logical block (matched non-greedily by perl).
#
#   au_set_block_hash <file> <anchor> <new-hash>
au_set_block_hash() {
  local file=$1 anchor=$2 hash=$3
  perl -0777 -pi -e \
    "s|(\\Q${anchor}\\E.*?hash\\s*=\\s*\")[^\"]+(\")|\${1}${hash}\${2}|s" \
    "$file"
}

# Replace `npmDepsHash = "..."` (single occurrence per file expected).
au_set_npm_deps_hash() {
  local file=$1 hash=$2
  au_inplace_sed "$file" \
    -e "s|npmDepsHash = \"sha256-[^\"]*\"|npmDepsHash = \"${hash}\"|"
}

# ---------------------------------------------------------------------------
# Build / validation
# ---------------------------------------------------------------------------

# Build a flake attribute with no symlink. Streams its log on failure so the
# updater script's `set -e` surfaces a useful error to the workflow log.
au_build() {
  local attr=$1
  if ! out=$(nix build "$attr" --no-link 2>&1); then
    printf '%s\n' "$out" >&2
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Workflow-level invariant guard
# ---------------------------------------------------------------------------

# Fails the workflow if an updater left:
#   - any FAKE placeholder hash in pkgs/, or
#   - any *.bak / *.bakN sed-shuffle artifact
# Run this once after the updater loop, before peter-evans/create-pull-request.
au_assert_clean() {
  local fail=0
  if rg -q 'sha256-AAAAAAAA' pkgs/ 2>/dev/null \
     || grep -RIlE 'sha256-AAAAAAAA' pkgs/ 2>/dev/null | grep -q .; then
    echo "::error::FAKE placeholder hashes remain in pkgs/:" >&2
    { rg -n 'sha256-AAAAAAAA' pkgs/ 2>/dev/null \
       || grep -RInE 'sha256-AAAAAAAA' pkgs/ 2>/dev/null; } >&2
    fail=1
  fi
  local stray
  stray=$(find pkgs -type f \( -name '*.bak' -o -name '*.bak[0-9]*' \) 2>/dev/null || true)
  if [ -n "$stray" ]; then
    echo "::error::stray sed .bak artifacts:" >&2
    printf '%s\n' "$stray" >&2
    fail=1
  fi
  return "$fail"
}

# Allow `bash scripts/lib/auto-update.sh assert-clean` from the workflow,
# avoiding having to source the lib in a separate shell step.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    assert-clean) au_assert_clean ;;
    *) echo "usage: $0 assert-clean" >&2; exit 2 ;;
  esac
fi
