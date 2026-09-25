#!/usr/bin/env bash
set -euo pipefail

workflow=$1

# Workflow steps only — a comment may name a check to explain it.
code=$(grep -vE '^\s*#' "$workflow")

# Each CI job builds every checks.<system> attribute the flake exposes, the way
# `just check` does. A hand-kept list drifted: fifteen unit checks ran in
# neither job, and the darwin job also skipped unit-auto-update.
if printf '%s\n' "$code" | grep -nE 'checks\.[a-z0-9_]+-(darwin|linux)\.[A-Za-z]'; then
  echo "build.yml: must not name individual checks; new ones would go unrun" >&2
  exit 1
fi
for system in x86_64-linux aarch64-darwin; do
  printf '%s\n' "$code" | grep -F "'.#checks.$system'" | grep -qF 'builtins.attrNames' || {
    echo "build.yml: must enumerate checks.$system with builtins.attrNames" >&2
    exit 1
  }
  printf '%s\n' "$code" | grep -qF ".#checks.$system.%s" || {
    echo "build.yml: must build every enumerated checks.$system name" >&2
    exit 1
  }
done
