# shellcheck shell=bash
# Shared by verify-session-path.sh and benchmark-shell-startup.sh: which
# interactive shell a dotfiles tree configures (martin.shell.interactive),
# which fish binary to run, and how to point fish at a built config.

# Print "fish" when $1 (a home or home-files dir) has a fish config and no
# .zshrc, "zsh" otherwise. A non-empty $2 overrides the detection.
interactive_shell_kind() {
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2"
  elif [ -e "$1/.config/fish/config.fish" ] && [ ! -e "$1/.zshrc" ]; then
    printf 'fish\n'
  else
    printf 'zsh\n'
  fi
}

# Print the fish to run: $1 when set, else the system profile's, else the
# first on PATH. Prints nothing when there is none.
fish_binary() {
  if [ -n "${1:-}" ]; then
    printf '%s\n' "$1"
  elif [ -x /run/current-system/sw/bin/fish ]; then
    printf '%s\n' /run/current-system/sw/bin/fish
  else
    command -v fish || true
  fi
}

# fish writes its variables file next to config.fish, so give it a writable
# $2/fish directory of links into the built $1/.config/fish.
link_fish_config() {
  local entry
  mkdir -p "$2/fish"
  for entry in "$1"/.config/fish/*; do
    ln -s "$entry" "$2/fish/"
  done
}
