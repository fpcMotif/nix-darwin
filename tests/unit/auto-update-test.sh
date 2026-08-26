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
glue_plan='these 3 derivations will be built:
  /nix/store/0000eeee1111ffff2222333344445555-claude-lsp.json.drv
  /nix/store/1111ffff222233334444555566667777-codex-lsp.toml.drv
  /nix/store/22223333444455556666777788889999-hm_LibraryFonts.homemanagerfontsversion.drv'
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
