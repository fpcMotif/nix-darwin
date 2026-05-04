#!/usr/bin/env bash
# Refresh every flake input via `nix flake update`. This is what keeps
# nixpkgs-tracked tooling (codex, zed-editor, nodejs_24, ruff, gopls, etc.),
# nix-darwin, home-manager, agent-skills, dotfiles, and friends current.
#
# Why a dedicated script: `.github/workflows/auto-update.yml` only iterates
# `scripts/update-*.sh`, so anything that lives only in flake inputs would
# otherwise never get bumped. Per-package update-*.sh scripts handle the
# vendored derivations under `pkgs/`; this one handles everything else.
#
# Idempotent — exits cleanly if no inputs changed since the last run.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

before=$(sha256sum flake.lock | awk '{print $1}')

# `nix flake update` writes the new lock and prints a summary of bumped
# inputs to stderr; surface that in the workflow log group.
nix flake update 2>&1 | tail -200

after=$(sha256sum flake.lock | awk '{print $1}')

if [ "$before" = "$after" ]; then
  echo "flake-inputs: already current"
  exit 0
fi

echo "flake-inputs: lockfile updated"
