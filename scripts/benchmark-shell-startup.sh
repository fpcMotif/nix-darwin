#!/usr/bin/env bash
# Benchmark shell startup times across modes and environments.
# Reports mean and spread via hyperfine, without encoding fragile CI thresholds.
#
# Usage:
#   bash scripts/benchmark-shell-startup.sh                   # live dotfiles
#   bash scripts/benchmark-shell-startup.sh "$HOME_FILES_DIR" # a built config before switching
#
#     HOME_FILES_DIR=$(nix build --no-link --print-out-paths \
#       .#darwinConfigurations.f.config.home-manager.users.martinfan.home-files)

set -euo pipefail

if ! command -v hyperfine >/dev/null 2>&1; then
  echo "error: hyperfine is required for startup benchmarking" >&2
  exit 1
fi

HOME_FILES_DIR="${1:-}"
ZDOTDIR_ARG=""
LABEL="live environment"

if [ -n "$HOME_FILES_DIR" ]; then
  if [ ! -d "$HOME_FILES_DIR" ]; then
    echo "error: HOME_FILES_DIR '$HOME_FILES_DIR' does not exist" >&2
    exit 1
  fi
  TMP_ZDOT=$(mktemp -d "${TMPDIR:-/tmp}/bench-zdot.XXXXXX")
  trap 'rm -rf "$TMP_ZDOT"' EXIT
  for f in .zshenv .zprofile .zshrc .zlogin; do
    if [ -f "$HOME_FILES_DIR/$f" ]; then
      cp "$HOME_FILES_DIR/$f" "$TMP_ZDOT/$f"
    fi
  done
  LABEL="built config ($HOME_FILES_DIR)"
  export ZDOTDIR="$TMP_ZDOT"
fi

echo "================================================================="
echo "Shell Startup Benchmark (${LABEL})"
echo "================================================================="

hyperfine --warmup 20 \
  --export-markdown "${TMPDIR:-/tmp}/shell-benchmark.md" \
  '/bin/zsh -f -i -c exit' \
  '/bin/zsh -c exit' \
  '/bin/zsh -l -c exit' \
  '/bin/zsh -i -c exit' \
  '/bin/zsh -lic exit'

if [ -f "${TMPDIR:-/tmp}/shell-benchmark.md" ]; then
  echo ""
  echo "Markdown Summary:"
  cat "${TMPDIR:-/tmp}/shell-benchmark.md"
  rm -f "${TMPDIR:-/tmp}/shell-benchmark.md"
fi
