# shellcheck shell=bash
set -euo pipefail

au_repo_root() {
  cd "$(dirname "${BASH_SOURCE[1]}")/.." > /dev/null && pwd
}

au_stdout_wants_color() {
  [ -z "${NO_COLOR:-}" ] && { [ -t 1 ] || [ "${FORCE_COLOR:-0}" != 0 ]; }
}

au_report_change() {
  local name=$1 old=$2 new=$3
  if au_stdout_wants_color; then
    printf '\033[1;36m%s\033[0m  \033[33m%s\033[0m \033[1;35m-->\033[0m \033[1;32m%s\033[0m\n' \
      "$name" "$old" "$new"
  else
    printf '%s  %s --> %s\n' "$name" "$old" "$new"
  fi
}

# A nixpkgs bump re-derives stdenv and rehashes the Darwin closure, so heavy
# inputs move only on the cadence day (issue #336). `nur` is heavy to contain
# lock churn, not build time, because Crush is a prebuilt-tarball repack.
AU_HEAVY_INPUTS="nixpkgs nur"

AU_CADENCE_DAY=1

au_today_weekday() {
  printf '%s\n' "${AU_WEEKDAY_OVERRIDE:-$(date -u +%u)}"
}

au_is_heavy_input() {
  local input=$1 heavy
  for heavy in $AU_HEAVY_INPUTS; do
    [ "$input" = "$heavy" ] && return 0
  done
  return 1
}

# A deny-list of heavy inputs, not an allow-list of light ones, so a newly
# added flake input never silently falls out of the nightly.
au_inputs_to_bump() {
  local day=$1; shift
  case "${AU_FORCE_FULL_BUMP:-0}" in
    # GitHub Actions boolean inputs deliver `true`.
    1|true) printf '%s\n' "$@"; return 0 ;;
  esac
  if [ "$day" = "$AU_CADENCE_DAY" ]; then
    printf '%s\n' "$@"
    return 0
  fi
  local input
  for input in "$@"; do
    au_is_heavy_input "$input" || printf '%s\n' "$input"
  done
}

# Comparing weekdays here would copy the cadence policy out of au_inputs_to_bump.
au_bump_mode() {
  local day=$1 heavy_inputs
  read -ra heavy_inputs <<<"$AU_HEAVY_INPUTS"
  if [ -n "$(au_inputs_to_bump "$day" "${heavy_inputs[@]}")" ]; then
    printf 'full\n'
  else
    printf 'light\n'
  fi
}

# Hydra can lag a nixpkgs revision on aarch64-darwin and force a ~30-minute
# compile of identical bytes (issue #336). Glue derivations appear in every
# plan and rebuild in milliseconds.
au_is_glue_drv_name() {
  local name=$1
  case "$name" in
    darwin-system-*|nixos-system-*|system-configurations*|\
    user-environment*|activation-*|*-activation-*|etc|etc-*|\
    system-path*|system-applications*)
      return 0 ;;
    home-manager-*|hm_*|options.json|fonts|source|patches)
      return 0 ;;
    npm-config-hook|hm-session-vars.sh|set-environment|ca-certificates.crt|\
    martin-auto-switch|*-auto-switch|*.plist|*.json|*.md|*.sh|*.yaml|*.yml|*.zsh|*.toml|*.ts|*.jq|\
    pstack-skill-*|worktrunk-marker|claude-settings-ownership|\
    *-config|*-settings|*-keymaps|*-models|*-report|*-report.domain|\
    *-extension-update.domain|python3-*-env|nix.conf|hm-modules-messages|\
    activate-system-start|link|cleanup|launchd|darwin-rebuild|\
    darwin-option|darwin-version*|darwin-uninstaller)
      return 0 ;;
    # LSP server package names never contain `-lsp.`, so only generated configs match.
    *-lsp.*)
      return 0 ;;
    darwin-manual*|darwin-help*|darwin-manpages*|*-manual-html|*-manpage*)
      return 0 ;;
  esac
  return 1
}

# Fresh CI runners rebuild a fixed-output download when the binary cache lacks
# its exact hash. That is a fetch, not source compilation.
au_is_fixed_output_drv() {
  local drv=$1
  nix derivation show "$drv" 2>/dev/null \
    | jq -e 'any(.derivations[]?.outputs[]?; .hash? != null)' >/dev/null
}

# Wrapper derivations extend the pname, as in zed-nightly-bin-wrapped-1.0.
au_is_vendored_drv_name() {
  local name=$1 pname
  shift
  for pname in "$@"; do
    case "$name" in "$pname"|"$pname"-*) return 0 ;; esac
  done
  return 1
}

# No binary cache holds a package defined in this repo. A hand-kept list would
# rot as pkgs/ changes.
au_vendored_drv_names() {
  local dir=${1:-pkgs}
  {
    grep -hoE '(pname|name) = "[^"]+"' "$dir"/*.nix 2>/dev/null \
      | cut -d'"' -f2
    # Packages imported from flake inputs have no pkgs/*.nix file.
    printf '%s\n' agent-skill agent-skills claude-code crush oh-my-pi opencode pi
    printf '%s\n' codex droid sourcegraph-amp zed-nightly-bin
    printf '%s\n' direnv skill-router tmux
  } | sort -u
}

# rust-overlay components unpack rust-lang's prebuilt archives. The match needs
# the version and target triple, so a from-source nixpkgs rustc-1.98.1 still fails.
au_is_rust_toolchain_drv_name() {
  [[ "$1" =~ ^rust-minimal-[0-9.]+$ ]] \
    || [[ "$1" =~ ^(rustc|cargo|rust-std|rust-src|clippy-preview|rustfmt-preview|rust-analyzer-preview)-[0-9.]+-(aarch64|x86_64)-(apple-darwin|unknown-linux-gnu)$ ]]
}

# Flagging only known offenders would let a new compile pass silently.
au_plan_offenders() {
  local in_build_section='' line name drv
  while IFS= read -r line; do
    case "$line" in
      *"will be built:") in_build_section=1 ;;
      *"will be fetched"*|*"will be copied"*|*"will be substituted") in_build_section='' ;;
      */nix/store/*-*.drv)
        [ -n "$in_build_section" ] || continue
        [[ "$line" =~ (/nix/store/[a-z0-9]{32}-([^[:space:]]+)\.drv) ]] || continue
        drv=${BASH_REMATCH[1]}
        name=${BASH_REMATCH[2]}
        if [ "${AU_SKIP_FIXED_OUTPUTS:-0}" = 1 ] && au_is_fixed_output_drv "$drv"; then
          continue
        fi
        au_is_glue_drv_name "$name" && continue
        au_is_rust_toolchain_drv_name "$name" && continue
        au_is_vendored_drv_name "$name" "$@" && continue
        printf '%s\n' "$name"
        ;;
    esac
  done
}

au_guard_source_builds() {
  local attr=${1:-.#darwinConfigurations.f.system} log offenders name
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

# AGENTS.md requires ax for HTTP.
au_http_get() {
  local url=$1
  shift
  if command -v ax >/dev/null 2>&1; then
    ax "$url" --body "$@"
  else
    curl -fsSL "$@" "$url"
  fi
}

# Updaters are tolerated to fail, so an unauthenticated 403 at 60 calls/hr would
# silently skip bumps. `gh` and CI each set a different one of GH_TOKEN and
# GITHUB_TOKEN.
au_github_api() {
  local url=$1
  local auth=()
  local token=${GITHUB_TOKEN:-${GH_TOKEN:-}}
  if [ -z "$token" ] && command -v gh >/dev/null 2>&1; then
    token=$(gh auth token 2>/dev/null || true)
  fi
  [ -n "$token" ] && auth=(-H "Authorization: Bearer ${token}")
  au_http_get "$url" ${auth[@]+"${auth[@]}"}
}

# Stable uses /releases/latest because `/releases?per_page=1 | .[0]` orders by
# creation date across all kinds. There a rolling tag like nubjs/nub's `canary`
# lands at `.[0]` and pins a version whose download URL 404s.
au_latest_github_release() {
  local repo=$1 strip=${2:-^v} channel=${3:-stable}
  local version
  if [ "$channel" = prerelease ]; then
    version=$(au_github_api "https://api.github.com/repos/${repo}/releases?per_page=30" \
          | jq -r '[.[] | select(.draft | not)] | sort_by(.published_at) | last | .tag_name // ""' \
          | sed "s|${strip}||")
  else
    version=$(au_github_api "https://api.github.com/repos/${repo}/releases/latest" \
          | jq -r '.tag_name // ""' | sed "s|${strip}||")
  fi
  if [ -z "$version" ] || [ "$version" = "null" ]; then
    echo "au_latest_github_release: empty tag for ${repo}" >&2
    return 1
  fi
  printf '%s\n' "$version"
}

# `sort -V` ranks 1.2.3-alpha.1 above 1.2.3. jq orders numbers before strings
# and a shorter array before its extensions, which matches semver precedence.
au_latest_semver() {
  jq -Rrs '
    split("\n") | map(select(length > 0))
    | max_by(
        sub("\\+.*$"; "") as $v
        | ($v | split("-")[0] | split(".") | map(tonumber)) as $core
        | ($v | (index("-") // null)) as $dash
        | if $dash == null then $core + [1, []]
          else $core + [0, ($v[$dash + 1:] | split(".") | map(tonumber? // .))]
          end
      ) // empty'
}

au_current_version() {
  local file=$1 range=${2:-}
  if [ -n "$range" ]; then
    awk "$range" "$file" \
      | grep -oE 'version = "[^"]+"' | head -1 | cut -d'"' -f2
  else
    grep -oE 'version = "[^"]+"' "$file" | head -1 | cut -d'"' -f2
  fi
}

au_nix32_sha256_to_sri() {
  nix hash convert --to sri --hash-algo sha256 "$1"
}

au_prefetch_sri() {
  local url=$1
  local nar
  nar=$(nix-prefetch-url --quiet "$url")
  au_nix32_sha256_to_sri "$nar"
}

# fetchFromGitHub and fetchzip hash the unpacked tree, not the tarball.
au_prefetch_unpacked_sri() {
  local url=$1
  local nar
  nar=$(nix-prefetch-url --unpack --quiet "$url")
  au_nix32_sha256_to_sri "$nar"
}

# GNU and BSD sed disagree on `-i`, and `-i.bak` leaves artifacts behind.
au_inplace_sed() {
  local file=$1; shift
  local tmp
  tmp=$(mktemp)
  if ! sed "$@" "$file" > "$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$file"
}

au_set_version() {
  local file=$1 ver=$2 range=${3:-}
  local expr="s|version = \"[^\"]*\"|version = \"${ver}\"|"
  if [ -n "$range" ]; then expr="${range} ${expr}"; fi
  au_inplace_sed "$file" -e "$expr"
}

# `set -e` ignores a failed command substitution used as an argument, so a
# 404'd prefetch reaches au_set_*_hash as "".
au_require_sri() {
  local hash=$1 ctx=$2
  case "$hash" in
    sha256-*|sha512-*) return 0 ;;
  esac
  echo "${ctx}: refusing to write non-SRI hash '${hash}' (prefetch likely failed)" >&2
  return 1
}

au_set_block_hash() {
  local file=$1 anchor=$2 hash=$3
  au_require_sri "$hash" "au_set_block_hash($file)" || return 1
  # `[^"]*` rather than `[^"]+` keeps an empty `hash = ""` repairable.
  perl -0777 -pi -e \
    "s|(\\Q${anchor}\\E.*?hash\\s*=\\s*\")[^\"]*(\")|\${1}${hash}\${2}|s" \
    "$file"
  # perl interpolates an anchor's `${version}` to nothing inside \Q..\E, and the
  # substitution then silently matches nothing.
  grep -qF "$hash" "$file" || {
    echo "au_set_block_hash: anchor '${anchor}' matched nothing in ${file}" >&2
    return 1
  }
}

au_build() {
  local attr=$1 out
  if ! out=$(nix build "$attr" --no-link 2>&1); then
    printf '%s\n' "$out" >&2
    return 1
  fi
}

# Linux CI still validates the pin through the overlay checks. build.yml
# performs the real Darwin build.
au_build_darwin() {
  local attr=$1
  if [ "$(uname -s)" != Darwin ]; then
    echo "${attr}: Darwin build deferred to macOS CI"
    return 0
  fi
  au_build "$attr"
}

# Any failure leaves the file byte-identical, so the version and every hash
# move together or not at all.
au_bump_release() {
  local name="" file="" version="" attr="" reverify=false
  local urls=() anchors=() unpacked=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --name) name=$2; shift 2 ;;
      --file) file=$2; shift 2 ;;
      --version) version=$2; shift 2 ;;
      --attr) attr=$2; shift 2 ;;
      # Some upstreams re-publish a release in place.
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

  # Downloads run concurrently because the network is the bottleneck.
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

au_in_github_actions() {
  [ "${GITHUB_ACTIONS:-}" = true ]
}

# Plain file copies, not git, because git writes desync the jj-colocated
# checkout (GLOSSARY.md, Colocated contract).
au_snapshot_pkgs_and_lock() {
  local snap=$1
  rm -rf -- "$snap/pkgs" "$snap/flake.lock"
  cp -a pkgs "$snap/pkgs"
  if [ -f flake.lock ]; then cp -a flake.lock "$snap/flake.lock"; fi
}

au_restore_pkgs_and_lock() {
  local snap=$1
  rm -rf -- pkgs.au-restore
  cp -a "$snap/pkgs" pkgs.au-restore
  rm -rf -- pkgs
  mv -- pkgs.au-restore pkgs
  if [ -f "$snap/flake.lock" ]; then cp -a "$snap/flake.lock" flake.lock; fi
}

# Restoring after a failed updater keeps a half-finished bump out of the
# nightly PR and a local switch.
au_run_updaters() {
  local scripts=("$@") snap s failed=0
  if [ ${#scripts[@]} -eq 0 ]; then
    scripts=(scripts/update-*.sh)
    [ -e "${scripts[0]}" ] || scripts=()
  fi
  snap=$(mktemp -d)
  for s in "${scripts[@]}"; do
    if au_in_github_actions; then echo "::group::$s"; else echo "=== $s ==="; fi
    au_snapshot_pkgs_and_lock "$snap"
    if ! bash "$s"; then
      failed=$((failed + 1))
      au_restore_pkgs_and_lock "$snap"
      if au_in_github_actions; then
        echo "::warning::$s failed; restored pkgs/ and flake.lock"
      else
        echo "$s failed; restored pkgs/ and flake.lock" >&2
      fi
    fi
    if au_in_github_actions; then echo "::endgroup::"; fi
  done
  rm -rf -- "$snap"
  if au_in_github_actions; then
    echo "::notice::$failed updater(s) failed (tolerated)"
  else
    echo "$failed updater(s) failed (tolerated)"
  fi
}

au_find_in_pkgs() {
  local pattern=$1
  rg -n "$pattern" pkgs/ 2>/dev/null \
    || grep -RInE "$pattern" pkgs/ 2>/dev/null
}

au_assert_clean() {
  local fail=0 matches
  local fake_hash='sha256-AAAAAAAA'
  local empty_hash='(hash|sha256|sha512|npmDepsHash|vendorHash|cargoHash) = ""'
  if matches=$(au_find_in_pkgs "$fake_hash"); then
    echo "::error::FAKE placeholder hashes remain in pkgs/:" >&2
    printf '%s\n' "$matches" >&2
    fail=1
  fi
  if matches=$(au_find_in_pkgs "$empty_hash"); then
    echo "::error::empty hash literals in pkgs/ (a prefetch failed):" >&2
    printf '%s\n' "$matches" >&2
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

# Workflows and the justfile call these subcommands instead of copying the
# cadence policy into YAML or sourcing the lib in a separate step.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  case "${1:-}" in
    assert-clean) au_assert_clean ;;
    bump-mode)
      day=${2:-$(au_today_weekday)}
      au_bump_mode "$day"
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
