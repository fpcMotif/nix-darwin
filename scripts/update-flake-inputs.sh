#!/usr/bin/env bash
# Refresh flake inputs under the weekly heavy/light cadence (issue #336).
#
# Light inputs — the vendored agent CLIs the operator tracks daily — bump
# every night. Heavy inputs (nixpkgs, nur) only move on the cadence day:
# bumping nixpkgs re-derives stdenv, which rehashes essentially every store
# path in the Darwin closure and turns a routine sync into a multi-gigabyte
# download or a from-source compile.
#
# The weekday decision is NOT made here: this script enumerates the flake's
# top-level inputs dynamically from `nix flake metadata` (a hand-maintained
# list would rot the first time an input is added), then hands them to the
# shared pure function in lib/auto-update.sh. Escape hatches:
#   AU_FORCE_FULL_BUMP=1  bump everything regardless of weekday
#   AU_WEEKDAY_OVERRIDE=1..7  pretend today is a different weekday
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

day=$(au_today_weekday)
mapfile -t all < <(nix flake metadata --json | jq -r '.locks.nodes.root.inputs | keys[]')
[ "${#all[@]}" -gt 0 ] || { echo "flake-inputs: no top-level inputs found" >&2; exit 1; }

mapfile -t bump < <(au_inputs_to_bump "$day" "${all[@]}")
[ "${#bump[@]}" -gt 0 ] || { echo "flake-inputs: nothing to bump today" >&2; exit 0; }

held=$(comm -23 \
  <(printf '%s\n' "${all[@]}" | sort) \
  <(printf '%s\n' "${bump[@]}" | sort))
if [ -n "$held" ]; then
  echo "flake-inputs: holding back until ISO weekday $AU_CADENCE_DAY: $(echo $held | tr '\n' ' ')"
fi

before=$(sha256sum flake.lock | awk '{print $1}')
nix flake update ${bump[@]+"${bump[@]}"} 2>&1 | tail -200
after=$(sha256sum flake.lock | awk '{print $1}')

if [ "$before" = "$after" ]; then
  echo "flake-inputs: already current"
  exit 0
fi
au_report_change flake-inputs "${before:0:12}" "${after:0:12}"
