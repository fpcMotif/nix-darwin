#!/usr/bin/env bash
set -euo pipefail

# Args: $1 library, $2 auto-switch module, $3 pkgs dir, $4 scripts dir,
#       $5 .github dir. All passed as store paths by tests/default.nix;
#       runnable locally with repo-relative paths.
lib=$1
auto_switch=$2
pkgs_dir=${3:-}
scripts_dir=${4:-}
github_dir=${5:-}

. "$lib"

fail() { echo "auto-update-test: $*" >&2; exit 1; }

has_word() { # has_word <word> <newline-separated-list>
  printf '%s\n' "$2" | grep -qxF "$1"
}

lacks_word() {
  ! has_word "$@"
}

# ---------------------------------------------------------------------------
# au_report_change (existing behaviour)
# ---------------------------------------------------------------------------

plain=$(NO_COLOR=1 au_report_change tool 1.33.55 1.33.80)
[ "$plain" = "tool  1.33.55 --> 1.33.80" ]

unset NO_COLOR
colored=$(FORCE_COLOR=1 au_report_change tool 1.33.55 1.33.80)
case "$colored" in
  *$'\033['*"tool"*$'\033['*"1.33.55"*"-->"*$'\033['*"1.33.80"*) ;;
  *) fail "colored update report missing ANSI fields: $colored" ;;
esac

# ---------------------------------------------------------------------------
# au_github_api: every GitHub API caller must authenticate when a token is
# present, so the 60/hr unauthenticated limit can't silently 403 a caller
# (reproduced 2026-09-15: update-squirrel.sh 403s under load because it
# bypassed this and curled api.github.com directly).
# ---------------------------------------------------------------------------

curl_argv_capture=$(mktemp)
ax() { printf '%s\n' "$*" > "$curl_argv_capture"; }
curl() { printf '%s\n' "$*" > "$curl_argv_capture"; }
unset GITHUB_TOKEN GH_TOKEN 2>/dev/null || true
au_github_api "https://api.github.com/repos/x/y/releases/latest" >/dev/null
captured=$(cat "$curl_argv_capture")
case "$captured" in
  *Authorization*) fail "au_github_api sent an auth header with no token present: $captured" ;;
esac

captured=$(GITHUB_TOKEN=tok123 au_github_api "https://api.github.com/repos/x/y/releases/latest" >/dev/null; cat "$curl_argv_capture")
case "$captured" in
  *"Authorization: Bearer tok123"*) ;;
  *) fail "au_github_api did not send GITHUB_TOKEN as a Bearer header: $captured" ;;
esac

captured=$(GH_TOKEN=tok456 au_github_api "https://api.github.com/repos/x/y/releases/latest" >/dev/null; cat "$curl_argv_capture")
case "$captured" in
  *"Authorization: Bearer tok456"*) ;;
  *) fail "au_github_api did not fall back to GH_TOKEN: $captured" ;;
esac

rm -f "$curl_argv_capture"
unset -f ax curl
# ---------------------------------------------------------------------------
# Cadence policy (issue #336): heavy inputs move only on the cadence day.
# ---------------------------------------------------------------------------

[ -n "${AU_HEAVY_INPUTS:-}" ] || fail "AU_HEAVY_INPUTS must be defined"
for h in nixpkgs nur; do
  case " $AU_HEAVY_INPUTS " in *" $h "*) ;; *) fail "heavy set must contain $h" ;; esac
done
case "$AU_CADENCE_DAY" in [1-7]) ;; *) fail "AU_CADENCE_DAY must be an ISO weekday 1-7, got '$AU_CADENCE_DAY'" ;; esac

sample="agent-skills darwin home-manager nixpkgs nur dotfiles"
heavy_list=$(printf '%s\n' $AU_HEAVY_INPUTS)
other_day=$([ "$AU_CADENCE_DAY" = 7 ] && echo 1 || echo $(( AU_CADENCE_DAY + 1 )))

# Cadence day: bump everything.
got=$(au_inputs_to_bump "$AU_CADENCE_DAY" $sample)
for i in $sample; do
  has_word "$i" "$got" || fail "cadence day dropped '$i': $got"
done

# Every other day: full set minus exactly the heavy names.
got=$(au_inputs_to_bump "$other_day" $sample)
for i in $sample; do
  if has_word "$i" "$heavy_list"; then
    lacks_word "$i" "$got" || fail "heavy input '$i' bumped on day $other_day: $got"
  else
    has_word "$i" "$got" || fail "light input '$i' held back on day $other_day: $got"
  fi
done

# Regression guard: an input unknown to the heavy set survives every day.
for day in 1 2 3 4 5 6 7; do
  got=$(au_inputs_to_bump "$day" some-future-input nixpkgs)
  has_word some-future-input "$got" \
    || fail "unknown input dropped on day $day: $got"
done

# Escape hatch: force a full bump regardless of weekday (accepts 1 or true,
# the latter being what GitHub Actions boolean inputs deliver).
got=$(AU_FORCE_FULL_BUMP=1 au_inputs_to_bump "$other_day" $sample | sort | tr '\n' ' ')
want=$(printf '%s\n' $sample | sort | tr '\n' ' ')
[ "$got" = "$want" ] || fail "force-full-bump did not restore the heavy set: $got"
got=$(AU_FORCE_FULL_BUMP=true au_inputs_to_bump "$other_day" $sample | sort | tr '\n' ' ')
[ "$got" = "$want" ] || fail "force-full-bump=true did not restore the heavy set: $got"

# Mode reporter used by the workflow's PR title/body.
mode=$(au_bump_mode "$AU_CADENCE_DAY")
[ "$mode" = "full" ] || fail "expected 'full' on cadence day, got '$mode'"
mode=$(au_bump_mode "$other_day")
[ "$mode" = "light" ] || fail "expected 'light' off cadence day, got '$mode'"
mode=$(AU_FORCE_FULL_BUMP=1 au_bump_mode "$other_day")
[ "$mode" = "full" ] || fail "forced mode must be 'full', got '$mode'"

# Weekday resolution honours the override so tests/manual runs skip the clock.
wd=$(AU_WEEKDAY_OVERRIDE=3 au_today_weekday)
[ "$wd" = "3" ] || fail "weekday override ignored: $wd"
wd=$(au_today_weekday)
case "$wd" in [1-7]) ;; *) fail "au_today_weekday returned '$wd'" ;; esac

# ---------------------------------------------------------------------------
# Build-plan classifier (issue #336): pure text -> offending derivations.
# ---------------------------------------------------------------------------

# Fixture: a clean nightly plan — glue derivations plus the vendored zed
# repack (captured from a real `nix build --dry-run` on the Darwin host,
# minus its preferLocalBuild entries).
clean_plan='these 6 derivations will be built:
  /nix/store/92f20s4b80yvh1plpsjjzz119qyyhnlm-darwin-manual-html.drv
  /nix/store/6bw3kksjh7ccgj1fr733cdhwn6s02wbl-home-configuration-reference-manpage.drv
  /nix/store/znnfvw7lxwyx2hybsbppcz25nj4iii77-zed-nightly-bin-wrapped-1.18.0+nightly.3229.drv
  /nix/store/hp7fnv8kw65v4xg2iwiqamxx6yw5wz4v-home-manager-fonts.drv
  /nix/store/9a0gppk2w8qgq3jn8633jny371hh6ipw-home-manager-files.drv
  /nix/store/mpmiyzr19wdzjkab1aaml9p28p7ddkcy-home-manager-path.drv'

out=$(printf '%s\n' "$clean_plan" | au_plan_offenders zed-nightly-bin)
[ -z "$out" ] || fail "clean plan flagged offenders: $out"

# A plan containing only vendored derivations passes.
vendored_plan='this derivation will be built:
  /nix/store/aaaa1111bbbb2222cccc3333dddd4444-drafts-mcp-server-0.3.1.drv
  /nix/store/bbbb2222cccc3333dddd4444eeee5555-sourcegraph-amp-0.1.2.drv'
out=$(printf '%s\n' "$vendored_plan" | au_plan_offenders drafts-mcp-server sourcegraph-amp)
[ -z "$out" ] || fail "vendored-only plan flagged offenders: $out"

# An uncached nixpkgs package fails, and the failure names it.
cold_plan='this derivation will be built:
  /nix/store/cccc3333dddd4444eeee5555ffff6666-nodejs-slim-26.7.0.drv'
out=$(printf '%s\n' "$cold_plan" | au_plan_offenders)
[ "$out" = "nodejs-slim-26.7.0" ] || fail "cold-cache offender not named: '$out'"

# A mixed plan names only the genuine offender.
mixed_plan='these 4 derivations will be built:
  /nix/store/dddd4444eeee5555ffff6666aaaa7777-home-manager-generation.drv
  /nix/store/eeee5555ffff6666aaaa7777bbbb8888-drafts-mcp-server-0.3.1.drv
  /nix/store/ffff6666aaaa7777bbbb8888cccc9999-vue-language-server-3.0.0.drv
  /nix/store/aaaa7777bbbb8888cccc9999dddd0000-hm-modules-messages.drv'
out=$(printf '%s\n' "$mixed_plan" | au_plan_offenders drafts-mcp-server)
[ "$out" = "vue-language-server-3.0.0" ] || fail "mixed plan verdict wrong: '$out'"

# Derivations in the fetch section are cached by definition — never offenders.
fetch_plan='these 1 derivations will be built:
  /nix/store/bbbb8888cccc9999dddd0000eeee1111-pnpm-10.15.0.drv

these 40 derivations will be fetched:
  /nix/store/cccc9999dddd0000eeee1111ffff2222-nodejs-slim-26.7.0.drv'
out=$(printf '%s\n' "$fetch_plan" | au_plan_offenders pnpm)
[ -z "$out" ] || fail "fetched section misclassified: $out"

# Generated config the name list still covers.
glue_plan='these 3 derivations will be built:
  /nix/store/0000eeee1111ffff2222333344445555-claude-lsp.json.drv
  /nix/store/444455556666777788889999aaaa0000-worktrunk-init.zsh.drv
  /nix/store/88889999aaaa00001111222233334444-worktrunk-marker.drv'
out=$(printf '%s\n' "$glue_plan" | au_plan_offenders)
[ -z "$out" ] || fail "generated-config glue flagged: $out"

# ---------------------------------------------------------------------------
# Impure exemption, gated by AU_INSPECT_DRVS=1. A stub `nix` logs each call
# and serves `nix derivation show` JSON trimmed to the fields the check reads.
# ---------------------------------------------------------------------------

nix_calls=$(mktemp)
nix() {
  printf '%s\n' "$3" >>"$nix_calls"
  local attrs
  case "$3" in
    *-tsgo.drv) attrs='"structuredAttrs":{"preferLocalBuild":true}' ;;
    *-pstack-skill-how.drv) attrs='"env":{"preferLocalBuild":"1"}' ;;
    *-vendor-staging.drv) attrs='"outputs":{"out":{"hash":"sha256-heJGLh0MgDPpksWyPLaIkZ5gVEWx8UnaJKv4GvclpmI="}}' ;;
    # Heavy compiles: attribute absent, false, and false in env ("").
    *-nodejs-slim-*.drv) attrs='"structuredAttrs":{"strictDeps":true}' ;;
    *-cocoapods-*.drv) attrs='"structuredAttrs":{"preferLocalBuild":false}' ;;
    *-vue-language-server-*.drv) attrs='"env":{"preferLocalBuild":""}' ;;
    *) return 1 ;;
  esac
  printf '{"derivations":{"%s":{%s}},"version":4}\n' "${3#/nix/store/}" "$attrs"
}

# Name-listed glue and vendored derivations never cost a nix call.
out=$(printf '%s\n' "$clean_plan" | AU_INSPECT_DRVS=1 au_plan_offenders zed-nightly-bin)
[ -z "$out" ] || fail "clean plan flagged offenders with the gate on: $out"
[ ! -s "$nix_calls" ] || fail "name-listed derivations reached nix: $(tr '\n' ' ' <"$nix_calls")"

# Both preferLocalBuild encodings and the fixed-output download pass; heavy
# compiles and a drv nix cannot show (libuv) stay offenders.
impure_plan='these 7 derivations will be built:
  /nix/store/0a0a1b1b2c2c3d3d4e4e5f5f6a6a7b7b-tsgo.drv
  /nix/store/1a1a1b1b2c2c3d3d4e4e5f5f6a6a7b7b-pstack-skill-how.drv
  /nix/store/2a2a1b1b2c2c3d3d4e4e5f5f6a6a7b7b-cryptography-50.0.0-vendor-staging.drv
  /nix/store/3a3a1b1b2c2c3d3d4e4e5f5f6a6a7b7b-nodejs-slim-24.20.0.drv
  /nix/store/4a4a1b1b2c2c3d3d4e4e5f5f6a6a7b7b-cocoapods-1.16.2.drv
  /nix/store/5a5a1b1b2c2c3d3d4e4e5f5f6a6a7b7b-vue-language-server-3.0.0.drv
  /nix/store/6a6a1b1b2c2c3d3d4e4e5f5f6a6a7b7b-libuv-1.51.0.drv'
out=$(printf '%s\n' "$impure_plan" | AU_INSPECT_DRVS=1 au_plan_offenders)
[ "$out" = $'nodejs-slim-24.20.0\ncocoapods-1.16.2\nvue-language-server-3.0.0\nlibuv-1.51.0' ] \
  || fail "impure plan verdict wrong: '$out'"
out=$(printf '%s\n' "$impure_plan" | au_plan_offenders)
has_word tsgo "$out" || fail "impure exemption applied with the gate off"
unset -f nix

# ---------------------------------------------------------------------------
# Vendored-exemption list: derived from the repo, so it cannot rot.
# ---------------------------------------------------------------------------

if [ -n "$pkgs_dir" ]; then
  vendored=$(au_vendored_drv_names "$pkgs_dir")
  [ -n "$vendored" ] || fail "au_vendored_drv_names found no pnames under pkgs/"
  while IFS= read -r v; do
    [ -n "$v" ] || fail "empty pname parsed from pkgs/"
    case "$v" in *[!A-Za-z0-9._-]*) fail "implausible pname parsed from pkgs/: '$v'" ;; esac
  done <<<"$vendored"
  for expected in drafts-mcp-server sourcegraph-amp; do
    has_word "$expected" "$vendored" \
      || fail "vendored list missing $expected; pkgs/ pnames no longer match reality"
  done
fi

# ---------------------------------------------------------------------------
# Wiring: the policy lives once and its consumers actually call it.
# ---------------------------------------------------------------------------

if [ -n "$scripts_dir" ]; then
  # The flake-inputs updater enumerates inputs dynamically (never a
  # hand-maintained list) and routes through the pure cadence function.
  grep -qE 'nix flake metadata' "$scripts_dir/update-flake-inputs.sh" \
    || fail "update-flake-inputs.sh must enumerate inputs via nix flake metadata"
  grep -qF 'au_inputs_to_bump' "$scripts_dir/update-flake-inputs.sh" \
    || fail "update-flake-inputs.sh must route through au_inputs_to_bump"
  # The crush updater cannot quietly bypass the heavy classification.
  grep -qF 'au_inputs_to_bump' "$scripts_dir/update-crush.sh" \
    || fail "update-crush.sh must adopt the cadence gate for nur"
  # Squirrel resolves its version from an asset name, not a tag, so it can't
  # use au_latest_github_release -- but it must still authenticate via
  # au_github_api rather than curling api.github.com unauthenticated.
  grep -qF 'au_github_api' "$scripts_dir/update-squirrel.sh" \
    || fail "update-squirrel.sh must poll the GitHub API via au_github_api (misses token auth)"
  if grep -qE 'curl[^|;]*api\.github\.com' "$scripts_dir/update-squirrel.sh"; then
    fail "update-squirrel.sh must not curl api.github.com directly, bypassing au_github_api auth"
  fi
fi

if [ -n "$github_dir" ]; then
  # The updater-library unit check actually runs in CI.
  grep -qF 'unit-auto-update' "$github_dir/workflows/build.yml" \
    || fail "build.yml does not run the unit-auto-update check"
  grep -qF 'unit-auto-update' "$github_dir/workflows/auto-update.yml" \
    || fail "auto-update.yml does not run the unit-auto-update check"
  # Source-build guard: hard step in the Darwin job, ahead of the system build.
  guard_line=$(grep -nF 'guard-source-builds' "$github_dir/workflows/build.yml" | head -1 | cut -d: -f1)
  [ -n "$guard_line" ] || fail "build.yml lacks the source-build guard step"
  sys_line=$(grep -nF 'Build darwinConfigurations.f' "$github_dir/workflows/build.yml" | head -1 | cut -d: -f1)
  [ -n "$sys_line" ] || fail "build.yml lacks the darwinConfigurations.f build step"
  [ "$guard_line" -lt "$sys_line" ] \
    || fail "source-build guard must run BEFORE the full system build (guard:$guard_line build:$sys_line)"
fi

# ---------------------------------------------------------------------------
# Structural greps over companion files (existing pattern)
# ---------------------------------------------------------------------------

grep -qF 'archive --format=tar' "$auto_switch"
grep -qF 'snapshot=$(mktemp -d' "$auto_switch"
if grep -qF 'git+file://' "$auto_switch"; then
  fail "auto-switch must not ask root Nix to open the user-owned Git repo"
fi

echo "auto-update-test: all assertions passed"
