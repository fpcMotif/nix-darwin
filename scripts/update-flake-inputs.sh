#!/usr/bin/env bash
# Refresh every flake input via `nix flake update`. Keeps nixpkgs-tracked
# tooling (codex, zed-editor, nodejs_24, ruff, gopls, etc.), nix-darwin,
# home-manager, agent-skills, dotfiles, NUR (crush), and friends current.
#
# Why a dedicated script: `.github/workflows/auto-update.yml` only iterates
# `scripts/update-*.sh`, so anything that lives only in flake inputs would
# otherwise never get bumped. Per-package update-*.sh scripts handle the
# vendored derivations under `pkgs/`; this one handles everything else.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

before=$(sha256sum flake.lock | awk '{print $1}')
nix flake update 2>&1 | tail -200
after=$(sha256sum flake.lock | awk '{print $1}')

if [ "$before" = "$after" ]; then
  echo "flake-inputs: already current"
  exit 0
fi
echo "flake-inputs: lockfile updated"
