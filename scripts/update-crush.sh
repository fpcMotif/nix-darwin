#!/usr/bin/env bash
# Refresh Crush through the official Charm NUR package.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

nix flake update nur
nix build .#crush --no-link

version=$(nix eval --raw .#crush.version 2>/dev/null || nix eval --raw .#crush.name)
echo "crush refreshed via Charm NUR at ${version}"
