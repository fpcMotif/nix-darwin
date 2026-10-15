#!/usr/bin/env bash
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

weekday=$(au_today_weekday)
# A hand-maintained input list would rot the first time an input is added.
mapfile -t all_inputs < <(nix flake metadata --json | jq -r '.locks.nodes.root.inputs | keys[]')
[ "${#all_inputs[@]}" -gt 0 ] || { echo "flake-inputs: no top-level inputs found" >&2; exit 1; }

mapfile -t inputs_to_bump < <(au_inputs_to_bump "$weekday" "${all_inputs[@]}")
[ "${#inputs_to_bump[@]}" -gt 0 ] || { echo "flake-inputs: nothing to bump today" >&2; exit 0; }

held_inputs=$(comm -23 \
  <(printf '%s\n' "${all_inputs[@]}" | sort) \
  <(printf '%s\n' "${inputs_to_bump[@]}" | sort) \
  | tr '\n' ' ')
if [ -n "$held_inputs" ]; then
  echo "flake-inputs: holding back until ISO weekday $AU_CADENCE_DAY: $held_inputs"
fi

lock_digest() {
  sha256sum flake.lock | awk '{print $1}'
}

before=$(lock_digest)
nix flake update "${inputs_to_bump[@]}" 2>&1 | tail -200
after=$(lock_digest)

if [ "$before" = "$after" ]; then
  echo "flake-inputs: already current"
  exit 0
fi
au_report_change flake-inputs "${before:0:12}" "${after:0:12}"
