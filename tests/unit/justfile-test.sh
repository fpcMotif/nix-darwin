#!/usr/bin/env bash
set -euo pipefail

justfile=$1

# The justfile comment above _daemon names the broken probe as a warning.
code=$(grep -vE '^\s*#' "$justfile")
has() { printf '%s\n' "$code" | grep -qF "$1"; }

# `nc -z` is TCP/UDP scan mode. Against a -U socket it exits non-zero even with a healthy daemon.
# `_daemon` would then sudo on every build and always report the daemon "still down".
if printf '%s\n' "$code" | grep -nE 'nc[^|;]*-z[^|;]*-U|nc[^|;]*-U[^|;]*-z|nc -zU'; then
  echo "justfile: 'nc -z' does not work on unix sockets; connect with 'nc -U -w' instead" >&2
  exit 1
fi

has 'nc -U -w 2 /nix/var/nix/daemon-socket/socket' || {
  echo "justfile: _daemon must probe the daemon socket with 'nc -U -w 2'" >&2
  exit 1
}

# Separate probes for the repair decision and its verification can drift apart.
[ "$(grep -cE '^\s*@?up\(\) \{' "$justfile")" -eq 1 ] || {
  echo "justfile: expected exactly one up() socket-probe helper in _daemon" >&2
  exit 1
}
has 'up || gone="$gone nix-daemon"' || {
  echo "justfile: up() must gate the preflight and queue nix-daemon for re-bootstrap" >&2
  exit 1
}
has 'if up && [ -e /run/current-system ]' || {
  echo "justfile: up() must also gate the post-bootstrap verification" >&2
  exit 1
}

# macOS wipes /run every boot, so a booted-out activate-system takes
# /run/current-system/sw/bin off PATH, and nix and darwin-rebuild with it.
has '[ -e /run/current-system ] && loaded activate-system' || {
  echo "justfile: _daemon must detect a booted-out activate-system / missing /run/current-system" >&2
  exit 1
}
has 'gone="$gone activate-system"' || {
  echo "justfile: _daemon must queue activate-system for re-bootstrap" >&2
  exit 1
}
for job in nix-gc nix-optimise nix-auto-switch; do
  has "$job" || {
    echo "justfile: _daemon must also re-bootstrap ${job}; BTM drops all org.nixos.* at once" >&2
    exit 1
  }
done

# A hand-kept list lets a new check run only under a bare `nix flake check`,
# which nothing in the repo invokes.
check_recipe=$(awk '/^check:/ { body = 1; next } body && /^[^ \t]/ { exit } body' "$justfile")
printf '%s\n' "$check_recipe" | grep -qF 'builtins.attrNames' || {
  echo "justfile: check must enumerate checks.<system> with builtins.attrNames" >&2
  exit 1
}
if printf '%s\n' "$check_recipe" | grep -nE 'checks\.[a-z0-9_]+-(darwin|linux)\.[A-Za-z]'; then
  echo "justfile: check must not name individual checks; new ones would go unrun" >&2
  exit 1
fi
printf '%s\n' "$check_recipe" | grep -qF '.#darwinConfigurations.f.system' || {
  echo "justfile: check must still build the full darwin system" >&2
  exit 1
}

# These recipes run nix, which fails while the daemon or activate-system is down.
for recipe in build switch update-and-switch bump-and-switch; do
  grep -qE "^${recipe}:.*\b_daemon\b" "$justfile" || {
    echo "justfile: recipe '${recipe}' must depend on _daemon" >&2
    exit 1
  }
done
