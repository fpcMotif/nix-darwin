#!/usr/bin/env bash
set -euo pipefail

lib=$1
auto_switch=$2
pkgs_dir=${3:-}
scripts_dir=${4:-}
github_dir=${5:-}

# shellcheck source=scripts/lib/auto-update.sh
. "$lib"

fail() { echo "auto-update-test: $*" >&2; exit 1; }

has_word() {
  local word=$1 newline_separated_list=$2
  printf '%s\n' "$newline_separated_list" | grep -qxF "$word"
}

lacks_word() {
  ! has_word "$@"
}

plain=$(NO_COLOR=1 au_report_change tool 1.33.55 1.33.80)
[ "$plain" = "tool  1.33.55 --> 1.33.80" ]

unset NO_COLOR
colored=$(FORCE_COLOR=1 au_report_change tool 1.33.55 1.33.80)
case "$colored" in
  *$'\033['*"tool"*$'\033['*"1.33.55"*"-->"*$'\033['*"1.33.80"*) ;;
  *) fail "colored update report missing ANSI fields: $colored" ;;
esac

# au_github_api must send any token present, or the 60/hr unauthenticated
# limit silently 403s a caller.
http_argv_capture=$(mktemp)
ax() { printf '%s\n' "$*" > "$http_argv_capture"; }
curl() { printf '%s\n' "$*" > "$http_argv_capture"; }
# A logged-in gh would supply a real token, and a failed assertion would print it.
gh() { return 1; }
unset GITHUB_TOKEN GH_TOKEN 2>/dev/null || true
au_github_api "https://api.github.com/repos/x/y/releases/latest" >/dev/null
captured=$(cat "$http_argv_capture")
case "$captured" in
  *Authorization*) fail "au_github_api sent an auth header with no token present: $captured" ;;
esac

captured=$(GITHUB_TOKEN=tok123 au_github_api "https://api.github.com/repos/x/y/releases/latest" >/dev/null; cat "$http_argv_capture")
case "$captured" in
  *"Authorization: Bearer tok123"*) ;;
  *) fail "au_github_api did not send GITHUB_TOKEN as a Bearer header: $captured" ;;
esac

captured=$(GH_TOKEN=tok456 au_github_api "https://api.github.com/repos/x/y/releases/latest" >/dev/null; cat "$http_argv_capture")
case "$captured" in
  *"Authorization: Bearer tok456"*) ;;
  *) fail "au_github_api did not fall back to GH_TOKEN: $captured" ;;
esac

rm -f "$http_argv_capture"
unset -f ax curl gh

# Semver ranks a release above its own pre-releases; `sort -V` does not.
latest=$(printf '%s\n' 0.48.0-alpha.3 0.48.0 0.47.9 | au_latest_semver)
[ "$latest" = 0.48.0 ] || fail "au_latest_semver ranked $latest above 0.48.0"
latest=$(printf '%s\n' 0.48.0-alpha.10 0.48.0-alpha.9 0.47.9 | au_latest_semver)
[ "$latest" = 0.48.0-alpha.10 ] || fail "au_latest_semver compared alpha numbers as text: $latest"
latest=$(printf '%s\n' 0.9.0 0.10.0-alpha.1 | au_latest_semver)
[ "$latest" = 0.10.0-alpha.1 ] || fail "au_latest_semver compared minor versions as text: $latest"

sed_scratch=$(mktemp -d)
mktemp() { command mktemp "$sed_scratch/tmp.XXXXXX"; }
printf 'version = "1"\n' > "$sed_scratch/pkg.nix"
if au_inplace_sed "$sed_scratch/pkg.nix" -e 's/unterminated' 2>/dev/null; then
  fail "au_inplace_sed reported success for an invalid sed expression"
fi
[ "$(cat "$sed_scratch/pkg.nix")" = 'version = "1"' ] || fail "au_inplace_sed changed the file after sed failed"
for leftover in "$sed_scratch"/tmp.*; do
  [ ! -e "$leftover" ] || fail "au_inplace_sed left its temp file after sed failed: $leftover"
done
unset -f mktemp
rm -rf "$sed_scratch"

# Heavy inputs move only on the cadence day (issue #336).
[ -n "${AU_HEAVY_INPUTS:-}" ] || fail "AU_HEAVY_INPUTS must be defined"
for heavy in nixpkgs nur; do
  case " $AU_HEAVY_INPUTS " in *" $heavy "*) ;; *) fail "heavy set must contain $heavy" ;; esac
done
case "$AU_CADENCE_DAY" in [1-7]) ;; *) fail "AU_CADENCE_DAY must be an ISO weekday 1-7, got '$AU_CADENCE_DAY'" ;; esac

sample=(agent-skills darwin home-manager nixpkgs nur dotfiles)
read -ra heavy_inputs <<<"$AU_HEAVY_INPUTS"
heavy_list=$(printf '%s\n' "${heavy_inputs[@]}")
other_day=$(( AU_CADENCE_DAY % 7 + 1 ))

got=$(au_inputs_to_bump "$AU_CADENCE_DAY" "${sample[@]}")
for i in "${sample[@]}"; do
  has_word "$i" "$got" || fail "cadence day dropped '$i': $got"
done

got=$(au_inputs_to_bump "$other_day" "${sample[@]}")
for i in "${sample[@]}"; do
  if has_word "$i" "$heavy_list"; then
    lacks_word "$i" "$got" || fail "heavy input '$i' bumped on day $other_day: $got"
  else
    has_word "$i" "$got" || fail "light input '$i' held back on day $other_day: $got"
  fi
done

# An input unknown to the heavy set must survive every day.
for day in 1 2 3 4 5 6 7; do
  got=$(au_inputs_to_bump "$day" some-future-input nixpkgs)
  has_word some-future-input "$got" \
    || fail "unknown input dropped on day $day: $got"
done

# GitHub Actions boolean inputs deliver `true`, not 1.
want=$(printf '%s\n' "${sample[@]}" | sort | tr '\n' ' ')
got=$(AU_FORCE_FULL_BUMP=1 au_inputs_to_bump "$other_day" "${sample[@]}" | sort | tr '\n' ' ')
[ "$got" = "$want" ] || fail "force-full-bump did not restore the heavy set: $got"
got=$(AU_FORCE_FULL_BUMP=true au_inputs_to_bump "$other_day" "${sample[@]}" | sort | tr '\n' ' ')
[ "$got" = "$want" ] || fail "force-full-bump=true did not restore the heavy set: $got"

mode=$(au_bump_mode "$AU_CADENCE_DAY")
[ "$mode" = "full" ] || fail "expected 'full' on cadence day, got '$mode'"
mode=$(au_bump_mode "$other_day")
[ "$mode" = "light" ] || fail "expected 'light' off cadence day, got '$mode'"
mode=$(AU_FORCE_FULL_BUMP=1 au_bump_mode "$other_day")
[ "$mode" = "full" ] || fail "forced mode must be 'full', got '$mode'"

weekday=$(AU_WEEKDAY_OVERRIDE=3 au_today_weekday)
[ "$weekday" = "3" ] || fail "weekday override ignored: $weekday"
weekday=$(au_today_weekday)
case "$weekday" in [1-7]) ;; *) fail "au_today_weekday returned '$weekday'" ;; esac

# Captured from a real `nix build --dry-run` on the Darwin host (issue #336).
clean_plan='these 9 derivations will be built:
  /nix/store/92f20s4b80yvh1plpsjjzz119qyyhnlm-darwin-manual-html.drv
  /nix/store/3gvl3rmw649ivqjjnfm1yiamy062f5qc-darwin-help.drv
  /nix/store/6bw3kksjh7ccgj1fr733cdhwn6s02wbl-home-configuration-reference-manpage.drv
  /nix/store/znnfvw7lxwyx2hybsbppcz25nj4iii77-zed-nightly-bin-wrapped-1.18.0+nightly.3229.drv
  /nix/store/hp7fnv8kw65v4xg2iwiqamxx6yw5wz4v-home-manager-fonts.drv
  /nix/store/9a0gppk2w8qgq3jn8633jny371hh6ipw-home-manager-files.drv
  /nix/store/mpmiyzr19wdzjkab1aaml9p28p7ddkcy-home-manager-path.drv
  /nix/store/jbpgb0sqf9qp5d1d8gzg24ldl84cjmpp-etc.drv
  /nix/store/hvq3xynf8mzpjiqkkz4cp6y39vqhy5p5-darwin-system-26.11.4cff07d.drv'

out=$(printf '%s\n' "$clean_plan" | au_plan_offenders zed-nightly-bin)
[ -z "$out" ] || fail "clean plan flagged offenders: $out"

vendored_plan='this derivation will be built:
  /nix/store/aaaa1111bbbb2222cccc3333dddd4444-drafts-mcp-server-0.3.1.drv
  /nix/store/bbbb2222cccc3333dddd4444eeee5555-sourcegraph-amp-0.1.2.drv'
out=$(printf '%s\n' "$vendored_plan" | au_plan_offenders drafts-mcp-server sourcegraph-amp)
[ -z "$out" ] || fail "vendored-only plan flagged offenders: $out"

cold_plan='this derivation will be built:
  /nix/store/cccc3333dddd4444eeee5555ffff6666-nodejs-slim-26.7.0.drv'
out=$(printf '%s\n' "$cold_plan" | au_plan_offenders)
[ "$out" = "nodejs-slim-26.7.0" ] || fail "cold-cache offender not named: '$out'"

mixed_plan='these 4 derivations will be built:
  /nix/store/dddd4444eeee5555ffff6666aaaa7777-user-environment.drv
  /nix/store/eeee5555ffff6666aaaa7777bbbb8888-drafts-mcp-server-0.3.1.drv
  /nix/store/ffff6666aaaa7777bbbb8888cccc9999-vue-language-server-3.0.0.drv
  /nix/store/aaaa7777bbbb8888cccc9999dddd0000-activation-martinfan.drv'
out=$(printf '%s\n' "$mixed_plan" | au_plan_offenders drafts-mcp-server)
[ "$out" = "vue-language-server-3.0.0" ] || fail "mixed plan verdict wrong: '$out'"

# Derivations in the fetch section are cached by definition.
fetch_plan='these 1 derivations will be built:
  /nix/store/bbbb8888cccc9999dddd0000eeee1111-pnpm-10.15.0.drv

these 40 derivations will be fetched:
  /nix/store/cccc9999dddd0000eeee1111ffff2222-nodejs-slim-26.7.0.drv'
out=$(printf '%s\n' "$fetch_plan" | au_plan_offenders pnpm)
[ -z "$out" ] || fail "fetched section misclassified: $out"

glue_plan='these 9 derivations will be built:
  /nix/store/0000eeee1111ffff2222333344445555-claude-lsp.json.drv
  /nix/store/0000ffff1111aaaa2222bbbb3333cccc-claude-settings-ownership.drv
  /nix/store/1111ffff222233334444555566667777-codex-lsp.toml.drv
  /nix/store/22223333444455556666777788889999-hm_LibraryFonts.homemanagerfontsversion.drv
  /nix/store/444455556666777788889999aaaa0000-worktrunk-init.zsh.drv
  /nix/store/55556666777788889999aaaa00001111-omp-routing.yml.drv
  /nix/store/6666777788889999aaaa000011112222-pstack-skill-how.drv
  /nix/store/777788889999aaaa0000111122223333-config.toml.drv
  /nix/store/88889999aaaa00001111222233334444-worktrunk-marker.drv'
out=$(printf '%s\n' "$glue_plan" | au_plan_offenders)
[ -z "$out" ] || fail "generated-config glue flagged: $out"

# rust-overlay names captured from a real Darwin plan. nixpkgs' from-source
# rustc and cargo must still fail.
rust_plan='these 10 derivations will be built:
  /nix/store/1111aaaa2222bbbb3333cccc4444dddd-rustc-1.99.0-aarch64-apple-darwin.drv
  /nix/store/2222bbbb3333cccc4444dddd5555eeee-cargo-1.99.0-aarch64-apple-darwin.drv
  /nix/store/3333cccc4444dddd5555eeee6666ffff-rust-std-1.99.0-aarch64-apple-darwin.drv
  /nix/store/4444dddd5555eeee6666ffff7777aaaa-rust-src-1.99.0-aarch64-apple-darwin.drv
  /nix/store/5555eeee6666ffff7777aaaa8888bbbb-clippy-preview-1.99.0-aarch64-apple-darwin.drv
  /nix/store/6666ffff7777aaaa8888bbbb9999cccc-rustfmt-preview-1.99.0-aarch64-apple-darwin.drv
  /nix/store/7777aaaa8888bbbb9999cccc0000dddd-rust-analyzer-preview-1.99.0-aarch64-apple-darwin.drv
  /nix/store/8888bbbb9999cccc0000dddd1111eeee-rust-minimal-1.99.0.drv
  /nix/store/9999cccc0000dddd1111eeee2222ffff-rustc-1.98.1.drv
  /nix/store/0000dddd1111eeee2222ffff3333aaaa-cargo-1.98.0.drv'
out=$(printf '%s\n' "$rust_plan" | au_plan_offenders)
[ "$out" = $'rustc-1.98.1\ncargo-1.98.0' ] || fail "rust toolchain verdict wrong: '$out'"

if [ -n "$pkgs_dir" ]; then
  vendored=$(au_vendored_drv_names "$pkgs_dir")
  [ -n "$vendored" ] || fail "au_vendored_drv_names found no pnames under pkgs/"
  while IFS= read -r pname; do
    [ -n "$pname" ] || fail "empty pname parsed from pkgs/"
    case "$pname" in *[!A-Za-z0-9._-]*) fail "implausible pname parsed from pkgs/: '$pname'" ;; esac
  done <<<"$vendored"
  for expected in drafts-mcp-server sourcegraph-amp calldiff; do
    has_word "$expected" "$vendored" \
      || fail "vendored list missing $expected; pkgs/ pnames no longer match reality"
  done
fi

# Each consumer must call the shared cadence policy rather than copy it.
if [ -n "$scripts_dir" ]; then
  grep -qE 'nix flake metadata' "$scripts_dir/update-flake-inputs.sh" \
    || fail "update-flake-inputs.sh must enumerate inputs via nix flake metadata"
  grep -qF 'au_inputs_to_bump' "$scripts_dir/update-flake-inputs.sh" \
    || fail "update-flake-inputs.sh must route through au_inputs_to_bump"
  grep -qF 'au_inputs_to_bump' "$scripts_dir/update-crush.sh" \
    || fail "update-crush.sh must adopt the cadence gate for nur"
  # An unauthenticated call 403s at 60 calls/hr, and a failed updater only skips its bump.
  for s in "$scripts_dir"/update-*.sh; do
    raw=$(grep -n 'api\.github\.com' "$s" | grep -v 'au_github_api' || true)
    [ -z "$raw" ] \
      || fail "$(basename "$s") reaches api.github.com outside au_github_api (misses token auth): $raw"
  done
fi

# A release pin moves its version and every hash together, or not at all.
pin_dir=$(mktemp -d)
export NO_COLOR=1

write_pin() {
  local version=$1 src_hash=$2 arm_hash=$3 x64_hash=$4
  cat > "$pin_dir/pin.nix" <<NIX
{ fetchurl, fetchzip }:
let
  version = "$version";
in {
  src = fetchzip {
    url = "https://example.test/archive/refs/tags/v\${version}.tar.gz";
    hash = "$src_hash";
  };
  arm = fetchurl {
    url = "https://example.test/v\${version}/tool-arm64";
    hash = "$arm_hash";
  };
  x64 = fetchurl {
    url = "https://example.test/v\${version}/tool-x64";
    hash = "$x64_hash";
  };
}
NIX
  cp "$pin_dir/pin.nix" "$pin_dir/before.nix"
}

au_prefetch_sri() {
  case "$1" in
    *fail*) return 1 ;;
    *malformed*) echo "" ;;
    *tool-arm64) echo "sha256-NEWARM=" ;;
    *tool-x64) echo "sha256-NEWX64=" ;;
    *) echo "sha256-OTHER=" ;;
  esac
}
au_prefetch_unpacked_sri() { echo "sha256-NEWSRC="; }
au_build_darwin() { echo "$1" >> "$pin_dir/builds"; [ -z "${AU_TEST_BUILD_FAIL:-}" ]; }

# X64_URL and X64_ANCHOR let a case break the x64 asset on its own.
bump() {
  local version=$1; shift
  au_bump_release --name tool --file "$pin_dir/pin.nix" --version "$version" --attr .#tool "$@" \
    --unpacked-asset "https://example.test/archive/refs/tags/v$version.tar.gz" 'archive/refs/tags' \
    --asset "https://example.test/v$version/tool-arm64" '/tool-arm64"' \
    --asset "${X64_URL:-https://example.test/v$version/tool-x64}" "${X64_ANCHOR:-/tool-x64\"}"
}

unchanged() { cmp -s "$pin_dir/before.nix" "$pin_dir/pin.nix"; }

write_pin 1.0.0 sha256-OLDSRC= sha256-OLDARM= sha256-OLDX64=
rm -f "$pin_dir/builds"
out=$(bump 1.0.0)
[ "$out" = "tool already at 1.0.0" ] || fail "current pin not reported as current: $out"
unchanged || fail "current pin was rewritten"
[ ! -e "$pin_dir/builds" ] || fail "current pin triggered a build"

out=$(bump 2.0.0)
grep -qF 'version = "2.0.0"' "$pin_dir/pin.nix" || fail "bump did not write the version"
for hash_name in NEWSRC NEWARM NEWX64; do
  grep -qF "hash = \"sha256-${hash_name}=\"" "$pin_dir/pin.nix" || fail "bump did not write $hash_name"
done
! grep -q 'sha256-OLD' "$pin_dir/pin.nix" || fail "bump left an old hash behind"
[ "$(cat "$pin_dir/builds")" = ".#tool" ] || fail "bump did not build .#tool once"
[ "$out" = "tool  1.0.0 --> 2.0.0" ] || fail "bump report wrong: $out"

write_pin 1.0.0 sha256-OLDSRC= sha256-OLDARM= sha256-OLDX64=
if X64_URL=https://example.test/fail/tool-x64 bump 2.0.0 2>/dev/null; then fail "failed download reported success"; fi
unchanged || fail "failed download changed the pin"
if X64_URL=https://example.test/malformed/tool-x64 bump 2.0.0 2>/dev/null; then fail "malformed hash reported success"; fi
unchanged || fail "malformed hash changed the pin"
if X64_ANCHOR='no-such-anchor' bump 2.0.0 2>/dev/null; then fail "unmatched anchor reported success"; fi
unchanged || fail "unmatched anchor changed the pin"
if AU_TEST_BUILD_FAIL=1 bump 2.0.0 >/dev/null 2>&1; then fail "failed build reported success"; fi
unchanged || fail "failed build left the new pin in place"

write_pin 2.0.0 sha256-NEWSRC= sha256-STALE= sha256-NEWX64=
rm -f "$pin_dir/builds"
bump 2.0.0 --reverify >/dev/null
grep -qF 'hash = "sha256-NEWARM="' "$pin_dir/pin.nix" || fail "reverify did not re-pin the stale hash"
grep -qF 'version = "2.0.0"' "$pin_dir/pin.nix" || fail "reverify changed the version"
[ -e "$pin_dir/builds" ] || fail "reverify re-pin skipped the build"
cp "$pin_dir/pin.nix" "$pin_dir/before.nix"
rm -f "$pin_dir/builds"
out=$(bump 2.0.0 --reverify)
unchanged || fail "steady-state reverify rewrote the pin"
[ ! -e "$pin_dir/builds" ] || fail "steady-state reverify triggered a build"
case "$out" in *"re-verified"*) ;; *) fail "steady-state reverify report wrong: $out" ;; esac

rm -rf "$pin_dir"
unset NO_COLOR
unset -f au_prefetch_sri au_prefetch_unpacked_sri au_build_darwin bump write_pin unchanged

# npm can stop receiving canaries, so one built over a week ago must fail
# instead of passing as "already at".
if [ -n "$scripts_dir" ]; then
  canary_dir=$(mktemp -d)
  mkdir -p "$canary_dir/scripts/lib" "$canary_dir/pkgs" "$canary_dir/bin"
  cp "$scripts_dir/update-bun-canary.sh" "$canary_dir/scripts/"
  cp "$lib" "$canary_dir/scripts/lib/auto-update.sh"
  echo 'version = "1.4.2-canary.20260925.1";' > "$canary_dir/pkgs/bun-canary-bin.nix"
  printf '%s\n' '#!/bin/sh' 'printf "{\"canary\":\"%s\"}\n" "$BC_CANARY"' > "$canary_dir/bin/ax"
  printf '%s\n' '#!/bin/sh' 'echo "$BC_CUTOFF"' > "$canary_dir/bin/date"
  chmod +x "$canary_dir/bin/ax" "$canary_dir/bin/date"
  bun_canary() {
    local npm_canary_version=$1 cutoff_yyyymmdd=$2
    PATH="$canary_dir/bin:$PATH" BC_CANARY=$npm_canary_version BC_CUTOFF=$cutoff_yyyymmdd NO_COLOR=1 \
      bash "$canary_dir/scripts/update-bun-canary.sh" 2>&1
  }

  out=$(bun_canary 1.4.2-canary.20260925.1 20260918) || fail "fresh canary failed: $out"
  [ "$out" = "bun-canary already at 1.4.2-canary.20260925.1" ] \
    || fail "fresh current canary misreported: $out"
  if out=$(bun_canary 1.4.2-canary.20260925.1 20261003); then fail "stale canary passed: $out"; fi
  case "$out" in *"over a week old"*) ;; *) fail "stale canary message wrong: $out" ;; esac
  if out=$(bun_canary 1.4.2 20260918); then fail "non-canary version passed: $out"; fi
  case "$out" in *"unexpected npm canary version"*) ;; *) fail "bad version message wrong: $out" ;; esac
  [ "$(cat "$canary_dir/pkgs/bun-canary-bin.nix")" = 'version = "1.4.2-canary.20260925.1";' ] \
    || fail "a refused canary changed the pin"
  rm -rf "$canary_dir"
  unset -f bun_canary
fi

# A failed updater must leave no half-finished bump and must not undo an
# earlier updater's success.
runner_dir=$(mktemp -d)
mkdir -p "$runner_dir/pkgs" "$runner_dir/scripts"
echo 'a = 1' > "$runner_dir/pkgs/a.nix"
echo 'b = 1' > "$runner_dir/pkgs/b.nix"
echo '{}' > "$runner_dir/flake.lock"
printf '%s\n' "echo 'a = 2' > pkgs/a.nix" > "$runner_dir/scripts/update-a.sh"
printf '%s\n' "echo 'b = 2' > pkgs/b.nix" "echo '{\"half\":true}' > flake.lock" \
  "touch pkgs/stray.nix" "exit 1" > "$runner_dir/scripts/update-b.sh"
out=$(cd "$runner_dir" && GITHUB_ACTIONS='' au_run_updaters 2>&1)
[ "$(cat "$runner_dir/pkgs/a.nix")" = 'a = 2' ] || fail "runner lost a successful updater's edit"
[ "$(cat "$runner_dir/pkgs/b.nix")" = 'b = 1' ] || fail "runner kept a failed updater's edit"
[ "$(cat "$runner_dir/flake.lock")" = '{}' ] || fail "runner kept a failed updater's flake.lock edit"
[ ! -e "$runner_dir/pkgs/stray.nix" ] || fail "runner kept a file a failed updater created"
case "$out" in *"1 updater(s) failed (tolerated)"*) ;; *) fail "runner miscounted failures: $out" ;; esac
rm -rf "$runner_dir"

if [ -n "$github_dir" ]; then
  # build.yml builds every check by name enumeration
  # (tests/unit/build-workflow-test.sh), so only the nightly workflow names it.
  grep -qF 'unit-auto-update' "$github_dir/workflows/auto-update.yml" \
    || fail "auto-update.yml does not run the unit-auto-update check"
  guard_line=$(grep -nF 'guard-source-builds' "$github_dir/workflows/build.yml" | head -1 | cut -d: -f1)
  [ -n "$guard_line" ] || fail "build.yml lacks the source-build guard step"
  sys_line=$(grep -nF 'Build darwinConfigurations.f' "$github_dir/workflows/build.yml" | head -1 | cut -d: -f1)
  [ -n "$sys_line" ] || fail "build.yml lacks the darwinConfigurations.f build step"
  [ "$guard_line" -lt "$sys_line" ] \
    || fail "source-build guard must run BEFORE the full system build (guard:$guard_line build:$sys_line)"
fi

grep -qF 'archive --format=tar' "$auto_switch"
grep -qF 'snapshot=$(mktemp -d' "$auto_switch"
if grep -qF 'git+file://' "$auto_switch"; then
  fail "auto-switch must not ask root Nix to open the user-owned Git repo"
fi

echo "auto-update-test: all assertions passed"
