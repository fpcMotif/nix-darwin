#!/usr/bin/env bash
# scripts/lib/check-group.sh — resolve a named check group into `nix build`
# attrpaths.
#
# Check-group membership lives in ONE place: `tests/default.nix`'s `groups`
# attrset, exposed as the `checkGroups.<system>` flake output. This script
# is the one place that turns a group name into `.#checks.<system>.<name>`
# attrpaths, so `.github/workflows/build.yml`, `justfile`, and
# `.github/workflows/auto-update.yml` enumerate a group instead of
# hardcoding attr-name lists.
#
# Usage: check-group.sh <system> <group>
# Prints one `.#checks.<system>.<name>` attrpath per line.
#
# `nix eval --json .#checkGroups.<system>.<group>` is attribute-name
# enumeration on a plain string list — lazy/pure, does not trigger a build
# (unlike building the checks themselves, which may hit the agent-skills
# import-from-derivation path on some group/system combinations).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <system> <group>" >&2
  exit 1
fi

system=$1
group=$2

nix eval --json ".#checkGroups.${system}.${group}" |
  jq -r --arg sys "$system" '.[] | ".#checks." + $sys + "." + .'
