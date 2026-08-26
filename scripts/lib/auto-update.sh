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

# One readable update line. Local terminals get color; redirected output stays
# plain unless FORCE_COLOR is set. NO_COLOR always wins.
au_report_change() {
  local name=$1 old=$2 new=$3
  if [ -z "${NO_COLOR:-}" ] \
     && { [ -t 1 ] || [ "${FORCE_COLOR:-0}" != 0 ]; }; then
    printf '\033[1;36m%s\033[0m  \033[33m%s\033[0m \033[1;35m-->\033[0m \033[1;32m%s\033[0m\n' \
      "$name" "$old" "$new"
  else
    printf '%s  %s --> %s\n' "$name" "$old" "$new"
  fi
}

# ---------------------------------------------------------------------------
# Update cadence (issue #336)
#
# Heavy inputs — their bump rehashes a large share of the Darwin baseline
# closure (a nixpkgs bump re-derives stdenv, which moves every store hash).
# They move only on the cadence day. `nur` is included for lock-churn
# containment, NOT because it compiles anything: Crush is a prebuilt-tarball
# repack whose "build" is an unpack-and-fixup taking seconds.
#
# Light inputs — every other top-level input, bumped nightly.
#
# The weekday decision is pure: string in (ISO weekday + input names),
# names out. The clock lives only in au_today_weekday; the workflows and
# justfile ask the library instead of duplicating the policy in YAML.
# ---------------------------------------------------------------------------

# Space-separated heavy set. Defined once here; every consumer reads it.
AU_HEAVY_INPUTS="nixpkgs nur"

# ISO weekday (1=Monday) on which heavy inputs are allowed to move,
# evaluated against the runner's UTC clock.
AU_CADENCE_DAY=1

# Today's ISO weekday in UTC. AU_WEEKDAY_OVERRIDE replaces the clock so
# tests and manual verification do not depend on the calendar.
au_today_weekday() {
  printf '%s\n' "${AU_WEEKDAY_OVERRIDE:-$(date -u +%u)}"
}

# Which top-level inputs to bump on the given ISO weekday?
#   au_inputs_to_bump <iso-weekday> <input-name>...
# Prints one input name per line. Cadence day -> everything; any other day
# -> everything minus the heavy set. Unknown inputs always survive: adding
# a new flake input can never silently fall out of the nightly.
# Set AU_FORCE_FULL_BUMP=1 (or true) to bump everything regardless of weekday.
au_inputs_to_bump() {
  local day=$1; shift
  case "${AU_FORCE_FULL_BUMP:-0}" in
    1|true) printf '%s\n' "$@"; return 0 ;;
  esac
  if [ "$day" = "$AU_CADENCE_DAY" ]; then
    printf '%s\n' "$@"
    return 0
  fi
  local input heavy skip
  for input in "$@"; do
    skip=''
    for heavy in $AU_HEAVY_INPUTS; do
      [ "$input" = "$heavy" ] && { skip=1; break; }
    done
    [ -n "$skip" ] || printf '%s\n' "$input"
  done
}

# Heavy-or-light verdict for tonight's run, used by the auto-update workflow
# to make heavy PRs visibly distinct from light PRs. With no input names,
# the heavy set itself is the question: "do the heavy inputs move today?"
#   au_bump_mode <iso-weekday> [input-name...]
au_bump_mode() {
  local day=$1; shift
  local bump heavy
  bump=$(printf '%s\n' "$(au_inputs_to_bump "$day" ${1+"$@"} $AU_HEAVY_INPUTS)")
  for heavy in $AU_HEAVY_INPUTS; do
    if printf '%s\n' "$bump" | grep -qxF "$heavy"; then
      printf 'full\n'; return 0
    fi
  done
  printf 'light\n'
}

# ---------------------------------------------------------------------------
# Source-build guard (issue #336)
#
# A nixpkgs-unstable revision can land where Hydra has not yet published an
# aarch64-darwin binary, forcing a ~30-minute local compile of a byte-identical
# artefact. The guard inspects a dry-run build plan and fails if it plans any
# from-source build outside the glue/vendored exemptions.
#
# Classification is by derivation NAME against two exemption classes:
#
#   Glue derivation — profile/activation/generated-config derivations that
#     appear in every build plan and rebuild in milliseconds. Never offenders.
#   Vendored derivation — packages defined in this repo (pkgs/*.nix pnames).
#     No binary cache will ever hold them; they always build locally by design.
#     The list is derived from the tree, so it cannot rot into fiction.
#
# Everything else IS a source build and fails. Erring toward failure means new
# noise surfaces immediately instead of silently green-lighting a compile.
# ---------------------------------------------------------------------------

au_is_glue_drv_name() {
  local name=$1
  case "$name" in
    # Top-level system / generation / activation derivations
    darwin-system-*|nixos-system-*|system-configurations*|\
    user-environment*|activation-*|*-activation-*|etc|etc-*|\
    system-path*|system-applications*)
      return 0 ;;
    # home-manager profiles, file trees, fonts, option docs
    home-manager-*|hm_*|options.json)
      return 0 ;;
    # Generated LSP config files (claude-lsp.json, codex-lsp.toml, …)
    *-lsp.*)
      return 0 ;;
    # Manuals and help pages
    darwin-manual*|darwin-help*|darwin-manpages*|*-manual-html|*-manpage*)
      return 0 ;;
  esac
  return 1
}

# Is <drv-name> covered by the given vendored pname list? A drv whose name
# starts with "<pname>-<version>" (e.g. zed-nightly-bin-wrapped-…) matches.
au_is_vendored_drv_name() {
  local name=$1 v
  shift
  for v in "$@"; do
    case "$name" in "$v"|"$v"-*) return 0 ;; esac
  done
  return 1
}

# Every package defined in this repo, as derivation-name prefixes. Derived
# from pkgs/* pnames at call time — the exemption list validates itself
# against reality rather than rotting into a hand-maintained fiction.
au_vendored_drv_names() {
  local dir=${1:-pkgs}
  grep -hoE 'pname = "[^"]+"' "$dir"/*.nix 2>/dev/null \
    | cut -d'"' -f2 | sort -u
}

# Pure classifier: read a dry-run build plan on stdin, print the NAMES of
# derivations that would build from source without an exemption.
#   au_plan_offenders <vendored-pname>...   (plan text on stdin)
au_plan_offenders() {
  local building='' line name
  while IFS= read -r line; do
    case "$line" in
      *"will be built:") building=1 ;;
      *"will be fetched"*|*"will be copied"*|*"will be substituted") building='' ;;
      */nix/store/*-*.drv)
        [ -n "$building" ] || continue
        [[ "$line" =~ /[a-z0-9]{32}-([^[:space:]]+)\.drv ]] || continue
        name=${BASH_REMATCH[1]}
        au_is_glue_drv_name "$name" && continue
        au_is_vendored_drv_name "$name" "$@" && continue
        printf '%s\n' "$name"
        ;;
    esac
  done
}

# Impure half: run the dry run, classify its plan, fail hard naming each
# offending derivation. No policy lives here beyond the message wording.
#   au_guard_source_builds [flake-attr]
au_guard_source_builds() {
  local attr=${1:-.#darwinConfigurations.f.system} log offenders
  if ! log=$(nix build "$attr" --dry-run --no-link --show-trace 2>&1); then
    printf '%s\n' "$log" >&2
    echo "source-build-guard: dry run failed; cannot verify the build plan" >&2
    return 1
  fi
  # shellcheck disable=SC2046  # pnames are single words (validated by unit test)
  offenders=$(printf '%s\n' "$log" | au_plan_offenders $(au_vendored_drv_names))
  if [ -n "$offenders" ]; then
    {
      echo "::error::source-build-guard: $attr would BUILD FROM SOURCE:"
      while IFS= read -r name; do
        echo "::error::  $name — no binary in the configured substituters"
      done <<<"$offenders"
      cat <<'EOF'
Remedies:
  - wait for cache.nixos.org to gain darwin coverage for this revision, or
  - hold the heavy inputs (nixpkgs, nur) on a revision with coverage:
      git checkout HEAD~1 -- flake.lock && just switch
A routine `just switch` must never compile from source; this revision may
not merge until the plan above is clean.
EOF
    } >&2
    return 1
  fi
  echo "source-build-guard: clean — every planned build is cached, glue, or vendored"
}

# ---------------------------------------------------------------------------
# Version polling
# ---------------------------------------------------------------------------

# Latest GitHub release tag. Defaults to the latest STABLE release via the
# /releases/latest endpoint, which is GitHub's own "newest non-draft,
# non-prerelease" query. Do NOT go back to `/releases?per_page=1 | .[0]`:
# that list is ordered by creation date across ALL release kinds, so a repo
# publishing a rolling prerelease tag hijacks the bump — nubjs/nub floated its
# `canary` tag to `.[0]` and the nightly rewrote nub.nix to version "canary"
# (whose download URL 404s).
#
# Pass `prerelease` as the 3rd arg to instead take the newest release of ANY
# kind (alpha/beta/rc), chosen by `published_at`. Drafts are always skipped.
#   au_latest_github_release <owner/repo> [strip-regex] [stable|prerelease]
au_latest_github_release() {
  local repo=$1 strip=${2:-^v} channel=${3:-stable}
  local v
  # Authenticate when a token is present so the GitHub API's 60/hr unauthed
  # limit can't silently 403 an updater (each is "tolerated to fail", so a
  # rate-limited run would just skip the bump). GH_TOKEN/GITHUB_TOKEN are the
  # conventional names; both `gh` and CI provide one.
  local auth=()
  local tok=${GITHUB_TOKEN:-${GH_TOKEN:-}}
  [ -n "$tok" ] && auth=(-H "Authorization: Bearer ${tok}")
  if [ "$channel" = prerelease ]; then
    v=$(curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/${repo}/releases?per_page=30" \
          | jq -r '[.[] | select(.draft | not)] | sort_by(.published_at) | last | .tag_name // ""' \
          | sed "s|${strip}||")
  else
    v=$(curl -fsSL ${auth[@]+"${auth[@]}"} "https://api.github.com/repos/${repo}/releases/latest" \
          | jq -r '.tag_name // ""' | sed "s|${strip}||")
  fi
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
    # Bleeding-edge priority: pick the first available tag. A single jq query
    # filters the priority list natively instead of spawning jq once per tag.
    local meta
    meta=$(curl -fsSL "https://registry.npmjs.org/${encoded}")
    v=$(printf '%s\n' "$meta" | jq -r '
      .["dist-tags"] |
      [ .canary, .dev, .next, .preview, .beta, .alpha, .rc, .latest ] |
      map(select(. != null and . != "")) |
      .[0] // ""
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

# Like au_prefetch_sri but also emits the downloaded store path, for callers
# that must inspect the asset bytes (e.g. `strings` a binary for its version).
# One download serves both. Line 1: SRI hash. Line 2: store path.
au_prefetch_sri_path() {
  local url=$1
  local out nar path
  out=$(nix-prefetch-url --print-path --quiet "$url")
  { IFS= read -r nar; IFS= read -r path; } <<<"$out"
  printf '%s\n%s\n' \
    "$(nix hash convert --to sri --hash-algo sha256 "$nar")" \
    "$path"
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

# Reject a hash that isn't a real SRI literal. Callers pass hashes as
# `au_set_*_hash "$FILE" "$(au_prefetch_sri "$url")"`, and bash does NOT let
# `set -e` fire when a command substitution used as an *argument* fails — so a
# 404'd prefetch silently yields "". Without this check that empty string gets
# written to the file and committed (this is exactly how pkgs/nub.nix ended up
# with `hash = ""`).
#   au_require_sri <hash> <context>
au_require_sri() {
  local hash=$1 ctx=$2
  case "$hash" in
    sha256-*|sha512-*) return 0 ;;
  esac
  echo "${ctx}: refusing to write non-SRI hash '${hash}' (prefetch likely failed)" >&2
  return 1
}

# Replace the `hash = "..."` line that follows an anchor (e.g. an attribute
# name like `"aarch64-darwin"` or a URL substring). The anchor and hash must
# live in the same logical block (matched non-greedily by perl).
#
# The old value is matched with `[^"]*` (not `+`) so an already-empty
# `hash = ""` is repairable rather than sticky. The post-check catches a silent
# no-op, e.g. an anchor containing `${version}`, which perl's \Q..\E
# interpolates away to nothing.
#
#   au_set_block_hash <file> <anchor> <new-hash>
au_set_block_hash() {
  local file=$1 anchor=$2 hash=$3
  au_require_sri "$hash" "au_set_block_hash($file)" || return 1
  perl -0777 -pi -e \
    "s|(\\Q${anchor}\\E.*?hash\\s*=\\s*\")[^\"]*(\")|\${1}${hash}\${2}|s" \
    "$file"
  grep -qF "$hash" "$file" || {
    echo "au_set_block_hash: anchor '${anchor}' matched nothing in ${file}" >&2
    return 1
  }
}

# Replace `npmDepsHash = "..."` (single occurrence per file expected).
au_set_npm_deps_hash() {
  local file=$1 hash=$2
  au_require_sri "$hash" "au_set_npm_deps_hash($file)" || return 1
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

# Build a Darwin-only package when running on Darwin. Linux CI still validates
# its pin through the overlay checks; build.yml performs the real Darwin build.
au_build_darwin() {
  local attr=$1
  if [ "$(uname -s)" != Darwin ]; then
    echo "${attr}: Darwin build deferred to macOS CI"
    return 0
  fi
  au_build "$attr"
}

# ---------------------------------------------------------------------------
# Workflow-level invariant guard
# ---------------------------------------------------------------------------

# Fails the workflow if an updater left:
#   - any FAKE placeholder hash in pkgs/,
#   - any empty `hash = ""` (a prefetch that failed and was written anyway), or
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
  if rg -q '(hash|sha256|sha512|npmDepsHash|vendorHash|cargoHash) = ""' pkgs/ 2>/dev/null \
     || grep -RIlE '(hash|sha256|sha512|npmDepsHash|vendorHash|cargoHash) = ""' pkgs/ 2>/dev/null | grep -q .; then
    echo "::error::empty hash literals in pkgs/ (a prefetch failed):" >&2
    { rg -n '(hash|sha256|sha512|npmDepsHash|vendorHash|cargoHash) = ""' pkgs/ 2>/dev/null \
       || grep -RInE '(hash|sha256|sha512|npmDepsHash|vendorHash|cargoHash) = ""' pkgs/ 2>/dev/null; } >&2
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

# Allow `bash scripts/lib/auto-update.sh <subcommand>` from workflows and
# local shells, avoiding having to source the lib in a separate step.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    assert-clean) au_assert_clean ;;
    bump-mode)
      # Heavy/light verdict for tonight's run; the auto-update workflow reads
      # it for the PR title/body. Honours AU_FORCE_FULL_BUMP/AU_WEEKDAY_OVERRIDE.
      day=${2:-$(au_today_weekday)}
      au_bump_mode "$day" $AU_HEAVY_INPUTS
      ;;
    guard-source-builds)
      shift
      au_guard_source_builds "${1:-}"
      ;;
    *) echo "usage: $0 {assert-clean|bump-mode [day]|guard-source-builds [attr]}" >&2; exit 2 ;;
  esac
fi
