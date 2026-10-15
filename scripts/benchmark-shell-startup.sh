#!/usr/bin/env bash
set -euo pipefail

if ! command -v hyperfine >/dev/null 2>&1; then
  echo "error: hyperfine is required for startup benchmarking" >&2
  exit 1
fi

HOME_FILES_DIR="${1:-}"
LABEL="live environment"
MARKDOWN_REPORT="${TMPDIR:-/tmp}/shell-benchmark.md"

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

# Report mean and spread only. CI thresholds on startup timings are fragile.
hyperfine --warmup 20 \
  --export-markdown "$MARKDOWN_REPORT" \
  '/bin/zsh -f -i -c exit' \
  '/bin/zsh -c exit' \
  '/bin/zsh -l -c exit' \
  '/bin/zsh -i -c exit' \
  '/bin/zsh -lic exit'

if [ -f "$MARKDOWN_REPORT" ]; then
  echo ""
  echo "Markdown Summary:"
  cat "$MARKDOWN_REPORT"
  rm -f "$MARKDOWN_REPORT"
fi
