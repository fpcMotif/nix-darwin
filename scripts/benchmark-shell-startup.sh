#!/usr/bin/env bash
# Benchmark shell startup times across modes and environments.
# Reports mean and spread via hyperfine, without encoding fragile CI thresholds,
# then times the first prompt and first command in a real pty
# (scripts/benchmark-first-prompt.py): exit timing never draws a prompt.
#
# Usage:
#   bash scripts/benchmark-shell-startup.sh                   # live dotfiles
#   bash scripts/benchmark-shell-startup.sh "$HOME_FILES_DIR" # a built config before switching
#
#     HOME_FILES_DIR=$(nix build --no-link --print-out-paths \
#       .#darwinConfigurations.f.config.home-manager.users.martinfan.home-files)
#
# The shell is the one the target configures, as in verify-session-path.sh:
# fish when it has .config/fish/config.fish and no .zshrc, zsh otherwise.
# BENCH_SHELL=zsh|fish overrides that; BENCH_FISH names the fish binary.
# BENCH_FIRST_PROMPT=0 skips the pty measurement; BENCH_PROMPT_MARKER is the
# text that marks the prompt (default ❯, as Starship and the fish prompt print).

set -euo pipefail

# The session exports CDPATH with "." first, which makes `cd` print the
# directory and corrupt `$(cd ... && pwd)`.
unset CDPATH

if ! command -v hyperfine >/dev/null 2>&1; then
  echo "error: hyperfine is required for startup benchmarking" >&2
  exit 1
fi

HOME_FILES_DIR="${1:-}"
LABEL="live environment"
WARMUP=20
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "$HOME_FILES_DIR" ] && [ ! -d "$HOME_FILES_DIR" ]; then
  echo "error: HOME_FILES_DIR '$HOME_FILES_DIR' does not exist" >&2
  exit 1
fi

. "$SCRIPT_DIR/lib/interactive-shell.sh"

SHELL_KIND=$(interactive_shell_kind "${HOME_FILES_DIR:-$HOME}" "${BENCH_SHELL:-}")

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bench-shell.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT
# Start in an empty directory, so no project .envrc loads at the prompt.
mkdir -p "$TMP_DIR/cwd"
declare -a child_env=()

case "$SHELL_KIND" in
  zsh)
    SHELL_BIN=/bin/zsh
    if [ -n "$HOME_FILES_DIR" ]; then
      mkdir -p "$TMP_DIR/zdot"
      for f in .zshenv .zprofile .zshrc .zlogin; do
        if [ -f "$HOME_FILES_DIR/$f" ]; then
          cp "$HOME_FILES_DIR/$f" "$TMP_DIR/zdot/$f"
        fi
      done
      export ZDOTDIR="$TMP_DIR/zdot"
      child_env+=("ZDOTDIR=$ZDOTDIR")
    fi
    commands=(
      "$SHELL_BIN -f -i -c exit"
      "$SHELL_BIN -c exit"
      "$SHELL_BIN -l -c exit"
      "$SHELL_BIN -i -c exit"
      "$SHELL_BIN -lic exit"
    )
    ;;
  fish)
    SHELL_BIN=$(fish_binary "${BENCH_FISH:-}")
    if [ -z "$SHELL_BIN" ]; then
      echo "error: fish not found; set BENCH_FISH" >&2
      exit 1
    fi
    if [ -n "$HOME_FILES_DIR" ]; then
      link_fish_config "$HOME_FILES_DIR" "$TMP_DIR/xdg-config"
      export XDG_CONFIG_HOME="$TMP_DIR/xdg-config"
      child_env+=("XDG_CONFIG_HOME=$XDG_CONFIG_HOME")
    fi
    # Without this cache fish's first interactive start scans man pages in
    # the background, which would load every later sample.
    mkdir -p "$TMP_DIR/cache/fish/generated_completions"
    export XDG_CACHE_HOME="$TMP_DIR/cache"
    child_env+=("XDG_CACHE_HOME=$XDG_CACHE_HOME")
    commands=(
      "$SHELL_BIN --no-config -i -c exit"
      "$SHELL_BIN -c exit"
      "$SHELL_BIN -l -c exit"
      "$SHELL_BIN -i -c exit"
      "$SHELL_BIN -lic exit"
    )
    ;;
  *)
    echo "error: BENCH_SHELL must be zsh or fish, got '$SHELL_KIND'" >&2
    exit 1
    ;;
esac

if [ -n "$HOME_FILES_DIR" ]; then
  LABEL="built config ($HOME_FILES_DIR)"
fi

echo "================================================================="
echo "Shell Startup Benchmark (${LABEL})"
echo "shell: $SHELL_KIND $SHELL_BIN ($("$SHELL_BIN" --version 2>/dev/null | head -n 1))"
echo "warmup: $WARMUP"
echo "================================================================="

cd "$TMP_DIR/cwd"
hyperfine --warmup "$WARMUP" \
  --export-markdown "$TMP_DIR/shell-benchmark.md" \
  "${commands[@]}"

echo ""
echo "Markdown Summary:"
cat "$TMP_DIR/shell-benchmark.md"

if [ "${BENCH_FIRST_PROMPT:-1}" != 0 ]; then
  echo ""
  declare -a set_args=()
  for kv in ${child_env[@]+"${child_env[@]}"}; do
    set_args+=(--set "$kv")
  done
  # A terminal starts a login shell, as Ghostty and tmux here do.
  uv run --script "$SCRIPT_DIR/benchmark-first-prompt.py" \
    --cwd "$TMP_DIR/cwd" --marker "${BENCH_PROMPT_MARKER:-❯}" \
    ${set_args[@]+"${set_args[@]}"} -- "$SHELL_BIN" -l
fi
