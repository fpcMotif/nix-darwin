#!/usr/bin/env bash
# Refresh app/tool flake inputs via `nix flake update <inputs>`. Keeps
# nixpkgs-tracked tooling (codex, nodejs_24, ruff, gopls, etc.), nix-darwin,
# home-manager, dotfiles, NUR (crush), and friends current.
#
# Why a dedicated script: `.github/workflows/auto-update.yml` only iterates
# `scripts/update-*.sh`, so anything that lives only in flake inputs would
# otherwise never get bumped. Per-package update-*.sh scripts handle the
# vendored derivations under `pkgs/`; this one handles everything else.
#
# Skill-content inputs are QUARANTINED from the auto-update. They feed the IFD
# skill bundle (`programs.agent-skills` / modules/home/claude.nix `mkSource` ->
# readFile SKILL.md), so an upstream bump can fail `nix flake check` with
# `…-safe.drv is not valid`, poisoning the shared eval guard in auto-update.yml
# and blocking every app/tool bump in the combined PR. They are skill content,
# not apps/tools, so we freeze their lock nodes here and bump them by hand (or
# via a dedicated job) once the bundle eval is hardened. Drop a name from
# QUARANTINE to let the auto-updater bump it again.
. "$(dirname "$0")/lib/auto-update.sh"
cd "$(au_repo_root)"

QUARANTINE=(agent-skills effect-ts-skills mattpocock-skills superpowers)

# Update every root input except the quarantined skill sources. Naming the
# inputs explicitly (rather than a blanket `nix flake update`) leaves the
# quarantined lock nodes byte-identical, so the guard keeps eval'ing the known-
# good skill pins.
to_update=()
while IFS= read -r inp; do
  skip=0
  for q in "${QUARANTINE[@]}"; do [ "$inp" = "$q" ] && skip=1; done
  [ "$skip" = 0 ] && to_update+=("$inp")
done < <(jq -r '.nodes[.root].inputs | keys[]' flake.lock)

if [ "${#to_update[@]}" -eq 0 ]; then
  echo "flake-inputs: nothing to update (all inputs quarantined)"
  exit 0
fi

echo "flake-inputs: updating ${to_update[*]}"
echo "flake-inputs: quarantined ${QUARANTINE[*]}"

before=$(sha256sum flake.lock | awk '{print $1}')
nix flake update "${to_update[@]}" 2>&1 | tail -200
after=$(sha256sum flake.lock | awk '{print $1}')

if [ "$before" = "$after" ]; then
  echo "flake-inputs: already current"
  exit 0
fi
echo "flake-inputs: lockfile updated"
