#!/usr/bin/env bash
set -euo pipefail

justfile=$1

# Recipe bodies only — the comment above _daemon names the broken probe on
# purpose, so scanning raw text would flag the very warning against it.
code=$(grep -vE '^\s*#' "$justfile")
has() { printf '%s\n' "$code" | grep -qF "$1"; }

# The nix-daemon preflight must probe the socket by actually connecting.
# `nc -z` is TCP/UDP scan mode and is a silent no-op against a -U socket: it
# exits non-zero even against a healthy daemon, which makes `_daemon` sudo on
# every single build and then always report the daemon "still down".
if printf '%s\n' "$code" | grep -nE 'nc[^|;]*-z[^|;]*-U|nc[^|;]*-U[^|;]*-z|nc -zU'; then
  echo "justfile: 'nc -z' does not work on unix sockets; connect with 'nc -U -w' instead" >&2
  exit 1
fi

has 'nc -U -w 2 /nix/var/nix/daemon-socket/socket' || {
  echo "justfile: _daemon must probe the daemon socket with 'nc -U -w 2'" >&2
  exit 1
}

# One probe helper, used both to decide whether repair is needed and to verify
# that it worked, so the two can never drift apart again.
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
# /run/current-system/sw/bin — and with it nix and darwin-rebuild — off PATH.
# The preflight has to restore that job, not just the daemon.
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

# Recipes that shell out to nix must not be reachable without the preflight.
for recipe in build switch update-and-switch bump-and-switch; do
  grep -qE "^${recipe}:.*\b_daemon\b" "$justfile" || {
    echo "justfile: recipe '${recipe}' must depend on _daemon" >&2
    exit 1
  }
done
