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
# A logged-in gh would supply a real token (and a failure would print it).
gh() { return 1; }
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
unset -f ax curl gh
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
# repack (captured from a real `nix build --dry-run` on the Darwin host).
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
  /nix/store/dddd4444eeee5555ffff6666aaaa7777-user-environment.drv
  /nix/store/eeee5555ffff6666aaaa7777bbbb8888-drafts-mcp-server-0.3.1.drv
  /nix/store/ffff6666aaaa7777bbbb8888cccc9999-vue-language-server-3.0.0.drv
  /nix/store/aaaa7777bbbb8888cccc9999dddd0000-activation-martinfan.drv'
out=$(printf '%s\n' "$mixed_plan" | au_plan_offenders drafts-mcp-server)
[ "$out" = "vue-language-server-3.0.0" ] || fail "mixed plan verdict wrong: '$out'"

# Derivations in the fetch section are cached by definition — never offenders.
fetch_plan='these 1 derivations will be built:
  /nix/store/bbbb8888cccc9999dddd0000eeee1111-pnpm-10.15.0.drv

these 40 derivations will be fetched:
  /nix/store/cccc9999dddd0000eeee1111ffff2222-nodejs-slim-26.7.0.drv'
out=$(printf '%s\n' "$fetch_plan" | au_plan_offenders pnpm)
[ -z "$out" ] || fail "fetched section misclassified: $out"

# Generated LSP config files and hm_* option trees are glue.
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
  # Every GitHub API poll authenticates: api.github.com may appear in an
  # updater only on an au_github_api line (update-squirrel.sh once 403'd by
  # curling it directly).
  for s in "$scripts_dir"/update-*.sh; do
    raw=$(grep -n 'api\.github\.com' "$s" | grep -v 'au_github_api' || true)
    [ -z "$raw" ] \
      || fail "$(basename "$s") reaches api.github.com outside au_github_api (misses token auth): $raw"
  done
fi

# ---------------------------------------------------------------------------
# au_bump_release: a release pin moves its version and every hash together,
# or not at all. Downloads and the Darwin build are stubbed.
# ---------------------------------------------------------------------------

rp=$(mktemp -d)
export NO_COLOR=1

write_pin() { # write_pin <version> <src-hash> <arm-hash> <x64-hash>
  cat > "$rp/pin.nix" <<NIX
{ fetchurl, fetchzip }:
let
  version = "$1";
in {
  src = fetchzip {
    url = "https://example.test/archive/refs/tags/v\${version}.tar.gz";
    hash = "$2";
  };
  arm = fetchurl {
    url = "https://example.test/v\${version}/tool-arm64";
    hash = "$3";
  };
  x64 = fetchurl {
    url = "https://example.test/v\${version}/tool-x64";
    hash = "$4";
  };
}
NIX
  cp "$rp/pin.nix" "$rp/before.nix"
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
au_build_darwin() { echo "$1" >> "$rp/builds"; [ -z "${AU_TEST_BUILD_FAIL:-}" ]; }

bump() { # bump <version> [extra args...]; x64 URL overridable via X64_URL
  local v=$1; shift
  au_bump_release --name tool --file "$rp/pin.nix" --version "$v" --attr .#tool "$@" \
    --unpacked-asset "https://example.test/archive/refs/tags/v$v.tar.gz" 'archive/refs/tags' \
    --asset "https://example.test/v$v/tool-arm64" '/tool-arm64"' \
    --asset "${X64_URL:-https://example.test/v$v/tool-x64}" "${X64_ANCHOR:-/tool-x64\"}"
}

unchanged() { cmp -s "$rp/before.nix" "$rp/pin.nix"; }

# Already current: no download, no write, no build.
write_pin 1.0.0 sha256-OLDSRC= sha256-OLDARM= sha256-OLDX64=
rm -f "$rp/builds"
out=$(bump 1.0.0)
[ "$out" = "tool already at 1.0.0" ] || fail "current pin not reported as current: $out"
unchanged || fail "current pin was rewritten"
[ ! -e "$rp/builds" ] || fail "current pin triggered a build"

# A bump writes the version and every hash, builds, and reports.
out=$(bump 2.0.0)
grep -qF 'version = "2.0.0"' "$rp/pin.nix" || fail "bump did not write the version"
for h in NEWSRC NEWARM NEWX64; do
  grep -qF "hash = \"sha256-${h}=\"" "$rp/pin.nix" || fail "bump did not write $h"
done
! grep -q 'sha256-OLD' "$rp/pin.nix" || fail "bump left an old hash behind"
[ "$(cat "$rp/builds")" = ".#tool" ] || fail "bump did not build .#tool once"
[ "$out" = "tool  1.0.0 --> 2.0.0" ] || fail "bump report wrong: $out"

# Every failure leaves the pin byte-identical.
write_pin 1.0.0 sha256-OLDSRC= sha256-OLDARM= sha256-OLDX64=
if X64_URL=https://example.test/fail/tool-x64 bump 2.0.0 2>/dev/null; then fail "failed download reported success"; fi
unchanged || fail "failed download changed the pin"
if X64_URL=https://example.test/malformed/tool-x64 bump 2.0.0 2>/dev/null; then fail "malformed hash reported success"; fi
unchanged || fail "malformed hash changed the pin"
if X64_ANCHOR='no-such-anchor' bump 2.0.0 2>/dev/null; then fail "unmatched anchor reported success"; fi
unchanged || fail "unmatched anchor changed the pin"
if AU_TEST_BUILD_FAIL=1 bump 2.0.0 >/dev/null 2>&1; then fail "failed build reported success"; fi
unchanged || fail "failed build left the new pin in place"

# --reverify: a re-published asset is re-pinned without a version change;
# a steady state stays byte-identical and skips the build.
write_pin 2.0.0 sha256-NEWSRC= sha256-STALE= sha256-NEWX64=
rm -f "$rp/builds"
bump 2.0.0 --reverify >/dev/null
grep -qF 'hash = "sha256-NEWARM="' "$rp/pin.nix" || fail "reverify did not re-pin the stale hash"
grep -qF 'version = "2.0.0"' "$rp/pin.nix" || fail "reverify changed the version"
[ -e "$rp/builds" ] || fail "reverify re-pin skipped the build"
cp "$rp/pin.nix" "$rp/before.nix"
rm -f "$rp/builds"
out=$(bump 2.0.0 --reverify)
unchanged || fail "steady-state reverify rewrote the pin"
[ ! -e "$rp/builds" ] || fail "steady-state reverify triggered a build"
case "$out" in *"re-verified"*) ;; *) fail "steady-state reverify report wrong: $out" ;; esac

rm -rf "$rp"
unset NO_COLOR
unset -f au_prefetch_sri au_prefetch_unpacked_sri au_build_darwin bump write_pin unchanged

# ---------------------------------------------------------------------------
# update-bun-canary.sh: npm published no bun canary from 2026-05-19 to
# 2026-08-20. A canary built more than a week ago fails the updater instead of
# passing as "already at". The registry (ax) and the clock (date) are stubbed.
# ---------------------------------------------------------------------------

if [ -n "$scripts_dir" ]; then
  bc=$(mktemp -d)
  mkdir -p "$bc/scripts/lib" "$bc/pkgs" "$bc/bin"
  cp "$scripts_dir/update-bun-canary.sh" "$bc/scripts/"
  cp "$lib" "$bc/scripts/lib/auto-update.sh"
  echo 'version = "1.4.2-canary.20260925.1";' > "$bc/pkgs/bun-canary-bin.nix"
  printf '%s\n' '#!/bin/sh' 'printf "{\"canary\":\"%s\"}\n" "$BC_CANARY"' > "$bc/bin/ax"
  printf '%s\n' '#!/bin/sh' 'echo "$BC_CUTOFF"' > "$bc/bin/date"
  chmod +x "$bc/bin/ax" "$bc/bin/date"
  bun_canary() { # bun_canary <npm canary version> <cutoff YYYYMMDD>
    PATH="$bc/bin:$PATH" BC_CANARY=$1 BC_CUTOFF=$2 NO_COLOR=1 \
      bash "$bc/scripts/update-bun-canary.sh" 2>&1
  }

  out=$(bun_canary 1.4.2-canary.20260925.1 20260918) || fail "fresh canary failed: $out"
  [ "$out" = "bun-canary already at 1.4.2-canary.20260925.1" ] \
    || fail "fresh current canary misreported: $out"
  if out=$(bun_canary 1.4.2-canary.20260925.1 20261003); then fail "stale canary passed: $out"; fi
  case "$out" in *"over a week old"*) ;; *) fail "stale canary message wrong: $out" ;; esac
  if out=$(bun_canary 1.4.2 20260918); then fail "non-canary version passed: $out"; fi
  case "$out" in *"unexpected npm canary version"*) ;; *) fail "bad version message wrong: $out" ;; esac
  [ "$(cat "$bc/pkgs/bun-canary-bin.nix")" = 'version = "1.4.2-canary.20260925.1";' ] \
    || fail "a refused canary changed the pin"
  rm -rf "$bc"
  unset -f bun_canary
fi

# ---------------------------------------------------------------------------
# au_run_updaters: a failed updater's edits to pkgs/ and flake.lock are put
# back; an earlier updater's success is kept.
# ---------------------------------------------------------------------------

ru=$(mktemp -d)
mkdir -p "$ru/pkgs" "$ru/scripts"
echo 'a = 1' > "$ru/pkgs/a.nix"
echo 'b = 1' > "$ru/pkgs/b.nix"
echo '{}' > "$ru/flake.lock"
printf '%s\n' "echo 'a = 2' > pkgs/a.nix" > "$ru/scripts/update-a.sh"
printf '%s\n' "echo 'b = 2' > pkgs/b.nix" "echo '{\"half\":true}' > flake.lock" \
  "touch pkgs/stray.nix" "exit 1" > "$ru/scripts/update-b.sh"
out=$(cd "$ru" && GITHUB_ACTIONS='' au_run_updaters 2>&1)
[ "$(cat "$ru/pkgs/a.nix")" = 'a = 2' ] || fail "runner lost a successful updater's edit"
[ "$(cat "$ru/pkgs/b.nix")" = 'b = 1' ] || fail "runner kept a failed updater's edit"
[ "$(cat "$ru/flake.lock")" = '{}' ] || fail "runner kept a failed updater's flake.lock edit"
[ ! -e "$ru/pkgs/stray.nix" ] || fail "runner kept a file a failed updater created"
case "$out" in *"1 updater(s) failed (tolerated)"*) ;; *) fail "runner miscounted failures: $out" ;; esac
rm -rf "$ru"

if [ -n "$github_dir" ]; then
  # The updater-library unit check actually runs in CI. build.yml builds every
  # check by name enumeration (tests/unit/build-workflow-test.sh), so only the
  # nightly workflow names it.
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
