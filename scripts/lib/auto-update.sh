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
    home-manager-*|hm_*|options.json|fonts|source|patches)
      return 0 ;;
    # Generated system files and activation helpers
    npm-config-hook|hm-session-vars.sh|set-environment|ca-certificates.crt|\
    martin-auto-switch|*-auto-switch|*.plist|*.json|*.md|*.sh|\
    *-config|*-settings|*-keymaps|*-models|*-report|*-report.domain|\
    *-extension-update.domain|python3-*-env|nix.conf|hm-modules-messages|\
    activate-system-start|link|cleanup|launchd|darwin-rebuild|\
    darwin-option|darwin-version*|darwin-uninstaller|check-link-targets.sh)
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

# Fixed-output derivations download a source/archive and do not compile it.
# Fresh CI runners legitimately rebuild these when the binary cache lacks the
# exact hash, so they must not be mistaken for source compilation.
au_is_fixed_output_drv() {
  local drv=$1
  nix derivation show "$drv" 2>/dev/null \
    | jq -e 'any(.derivations[]?.outputs[]?; .hash? != null)' >/dev/null
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

# Packages imported from flake inputs are not represented by pkgs/*.nix.
# Keep their derivation prefixes in the same local-build exemption.
au_vendored_drv_names() {
  local dir=${1:-pkgs}
  {
    grep -hoE 'pname = "[^"]+"' "$dir"/*.nix 2>/dev/null \
      | cut -d'"' -f2
    printf '%s\n' agent-skills claude-code crush oh-my-pi opencode pi
    printf '%s\n' codex droid sourcegraph-amp zed-nightly-bin
    printf '%s\n' direnv skill-router tmux
  } | sort -u
}

au_plan_offenders() {
  local building='' line name drv
  while IFS= read -r line; do
    case "$line" in
      *"will be built:") building=1 ;;
      *"will be fetched"*|*"will be copied"*|*"will be substituted") building='' ;;
      */nix/store/*-*.drv)
        [ -n "$building" ] || continue
        [[ "$line" =~ (/nix/store/[a-z0-9]{32}-([^[:space:]]+)\.drv) ]] || continue
        drv=${BASH_REMATCH[1]}
        name=${BASH_REMATCH[2]}
        if [ "${AU_SKIP_FIXED_OUTPUTS:-0}" = 1 ] && au_is_fixed_output_drv "$drv"; then
          continue
        fi
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
  offenders=$(printf '%s\n' "$log" | AU_SKIP_FIXED_OUTPUTS=1 au_plan_offenders $(au_vendored_drv_names))
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

# HTTP GET using `ax --body` when available (AGENTS.md contract), with
# `curl -fsSL` fallback for environments without ax.
#   au_http_get <url> [headers/options...]
au_http_get() {
  local url=$1
  shift
  if command -v ax >/dev/null 2>&1; then
    ax "$url" --body "$@"
  else
    curl -fsSL "$@" "$url"
  fi
}

# Authenticated GitHub API GET; prints the raw response body. Every updater
# that talks to api.github.com must route through this (directly, or via
# au_latest_github_release below) so the API's 60/hr unauthenticated limit
# can't silently 403 it — each updater is "tolerated to fail", so a
# rate-limited run would just skip the bump. GH_TOKEN/GITHUB_TOKEN are the
# conventional names; both `gh` and CI provide one.
#   au_github_api <url>
au_github_api() {
  local url=$1
  local auth=()
  local tok=${GITHUB_TOKEN:-${GH_TOKEN:-}}
  if [ -z "$tok" ] && command -v gh >/dev/null 2>&1; then
    tok=$(gh auth token 2>/dev/null || true)
  fi
  [ -n "$tok" ] && auth=(-H "Authorization: Bearer ${tok}")
  au_http_get "$url" ${auth[@]+"${auth[@]}"}
}

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
  if [ "$channel" = prerelease ]; then
    v=$(au_github_api "https://api.github.com/repos/${repo}/releases?per_page=30" \
          | jq -r '[.[] | select(.draft | not)] | sort_by(.published_at) | last | .tag_name // ""' \
          | sed "s|${strip}||")
  else
    v=$(au_github_api "https://api.github.com/repos/${repo}/releases/latest" \
          | jq -r '.tag_name // ""' | sed "s|${strip}||")
  fi
  [ -n "$v" ] && [ "$v" != "null" ] || {
    echo "au_latest_github_release: empty tag for ${repo}" >&2; return 1
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
# Release pin bump
# ---------------------------------------------------------------------------

# Bump a release pin (CONTEXT.md): one upstream version plus the hash of each
# file the package downloads. The caller resolves the upstream version; this
# owns compare, download, hash, rewrite, build, and report.
#
#   au_bump_release --name NAME --file FILE --version VERSION --attr FLAKE_ATTR
#                   [--reverify]
#                   --asset URL ANCHOR [--asset URL ANCHOR ...]
#                   [--unpacked-asset URL ANCHOR ...]
#
# ANCHOR is text unique to the block that holds that download's `hash = "…"`
# (see au_set_block_hash); it must not contain a literal `${version}`.
# --unpacked-asset hashes the unpacked tree (fetchzip / fetchFromGitHub).
# --reverify re-downloads and re-pins every hash even when the version is
# unchanged, for upstreams that re-publish a release in place.
#
# Guarantee: on any failure (a download, a malformed hash, an anchor that
# matches nothing, or the Darwin build) FILE is left byte-identical. The
# version and every hash move together or not at all.
au_bump_release() {
  local name="" file="" version="" attr="" reverify=false
  local urls=() anchors=() unpacked=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --name) name=$2; shift 2 ;;
      --file) file=$2; shift 2 ;;
      --version) version=$2; shift 2 ;;
      --attr) attr=$2; shift 2 ;;
      --reverify) reverify=true; shift ;;
      --asset | --unpacked-asset)
        [ $# -ge 3 ] || { echo "au_bump_release: $1 needs URL and ANCHOR" >&2; return 2; }
        urls+=("$2"); anchors+=("$3")
        if [ "$1" = --unpacked-asset ]; then unpacked+=(true); else unpacked+=(false); fi
        shift 3 ;;
      *) echo "au_bump_release: unknown argument '$1'" >&2; return 2 ;;
    esac
  done
  if [ -z "$name" ] || [ -z "$file" ] || [ -z "$attr" ] || [ ${#urls[@]} -eq 0 ]; then
    echo "au_bump_release: --name, --file, --attr, and one --asset are required" >&2
    return 2
  fi
  if [ -z "$version" ] || [ "$version" = null ]; then
    echo "${name}: empty upstream version" >&2
    return 1
  fi

  local current
  current=$(au_current_version "$file")
  if [ "$current" = "$version" ] && [ "$reverify" = false ]; then
    echo "$name already at $version"
    return 0
  fi

  # Download every asset before touching FILE, concurrently: the network is
  # the bottleneck. Wait for every job so none outlives this function.
  local work i failed=0 pids=()
  work=$(mktemp -d)
  for i in "${!urls[@]}"; do
    if [ "${unpacked[$i]}" = true ]; then
      (au_prefetch_unpacked_sri "${urls[$i]}" > "$work/hash.$i") &
    else
      (au_prefetch_sri "${urls[$i]}" > "$work/hash.$i") &
    fi
    pids+=($!)
  done
  for i in "${!pids[@]}"; do
    wait "${pids[$i]}" || { echo "${name}: download failed: ${urls[$i]}" >&2; failed=1; }
  done
  if [ "$failed" -ne 0 ]; then
    rm -rf -- "$work"
    return 1
  fi

  # Apply every edit to a scratch copy; FILE changes only once all succeed.
  cp -- "$file" "$work/new.nix"
  if [ "$current" != "$version" ]; then
    au_set_version "$work/new.nix" "$version"
  fi
  for i in "${!urls[@]}"; do
    if ! au_set_block_hash "$work/new.nix" "${anchors[$i]}" "$(< "$work/hash.$i")"; then
      rm -rf -- "$work"
      return 1
    fi
  done

  if cmp -s "$work/new.nix" "$file"; then
    rm -rf -- "$work"
    echo "$name already at $version (asset hashes re-verified)"
    return 0
  fi

  cp -- "$file" "$work/old.nix"
  cp -- "$work/new.nix" "$file"
  if ! au_build_darwin "$attr"; then
    cp -- "$work/old.nix" "$file"
    rm -rf -- "$work"
    echo "${name}: build failed; restored $file" >&2
    return 1
  fi
  rm -rf -- "$work"

  if [ "$current" = "$version" ]; then
    au_report_change "$name" "$version" "$version (re-published assets re-pinned)"
  else
    au_report_change "$name" "$current" "$version"
  fi
}

# ---------------------------------------------------------------------------
# Updater runner
# ---------------------------------------------------------------------------

# Run updaters in turn and tolerate each failure. Before each updater, copy
# pkgs/ and flake.lock aside; when it fails, put them back, so a half-finished
# bump never reaches the nightly PR or a local switch. Plain file copies, not
# git: the local checkout is jj-colocated, and git writes desync jj
# (CONTEXT.md, Colocated contract). Run from the repo root.
#   au_run_updaters [script...]    (default: every scripts/update-*.sh)
au_run_updaters() {
  local scripts=("$@") snap s failed=0
  if [ ${#scripts[@]} -eq 0 ]; then
    scripts=(scripts/update-*.sh)
    [ -e "${scripts[0]}" ] || scripts=()
  fi
  snap=$(mktemp -d)
  for s in "${scripts[@]}"; do
    if [ "${GITHUB_ACTIONS:-}" = true ]; then echo "::group::$s"; else echo "=== $s ==="; fi
    rm -rf -- "$snap/pkgs" "$snap/flake.lock"
    cp -a pkgs "$snap/pkgs"
    if [ -f flake.lock ]; then cp -a flake.lock "$snap/flake.lock"; fi

    if ! bash "$s"; then
      failed=$((failed + 1))
      rm -rf -- pkgs.au-restore
      cp -a "$snap/pkgs" pkgs.au-restore
      rm -rf -- pkgs
      mv -- pkgs.au-restore pkgs
      if [ -f "$snap/flake.lock" ]; then cp -a "$snap/flake.lock" flake.lock; fi
      if [ "${GITHUB_ACTIONS:-}" = true ]; then
        echo "::warning::$s failed; restored pkgs/ and flake.lock"
      else
        echo "$s failed; restored pkgs/ and flake.lock" >&2
      fi
    fi
    if [ "${GITHUB_ACTIONS:-}" = true ]; then echo "::endgroup::"; fi
  done
  rm -rf -- "$snap"
  if [ "${GITHUB_ACTIONS:-}" = true ]; then
    echo "::notice::$failed updater(s) failed (tolerated)"
  else
    echo "$failed updater(s) failed (tolerated)"
  fi
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
    run-updaters)
      shift
      cd "$(dirname "${BASH_SOURCE[0]}")/../.."
      au_run_updaters "$@"
      ;;
    *) echo "usage: $0 {assert-clean|bump-mode [day]|guard-source-builds [attr]|run-updaters [script...]}" >&2; exit 2 ;;
  esac
fi
