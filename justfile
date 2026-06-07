# Top-level developer recipes for nix-config. Run `just` for the list,
# `just <recipe>` to invoke. Mirrored by the `drs` / `drb` zsh aliases.
#
# IMPORTANT: never run `just` itself with `sudo`. Recipes that need root
# call `sudo` internally; running the outer `just` as root makes git
# evaluate the flake as user 0, which libgit2 refuses on a user-owned
# checkout (`repository path '...' is not owned by current user`).

# Refuse to proceed if just was invoked with elevated privileges. Avoids
# the libgit2 ownership error during darwin-rebuild evaluation.
_no-sudo:
    @if [ "${EUID:-$(id -u)}" -eq 0 ]; then \
        echo 'just: do not run me with sudo. Run `just switch` (no sudo); the recipe sudos darwin-rebuild itself.' >&2; \
        exit 1; \
    fi

# Default: print available recipes.
default: _no-sudo
    @just --list

# Build (no activate) the darwin system from the working tree. Use this
# to dry-run a change before committing to a switch.
build: _no-sudo
    darwin-rebuild build --flake .

# Activate the working-tree configuration (system + home-manager).
switch: _no-sudo
    sudo darwin-rebuild switch --flake .

# Bump every flake input to its latest revision, then activate.
update-and-switch: _no-sudo
    nix flake update
    sudo darwin-rebuild switch --flake .

# Run every scripts/update-*.sh updater, then activate. This is what the
# hourly auto-update GitHub workflow does, but on-demand.
bump-and-switch: _no-sudo
    for s in scripts/update-*.sh; do echo "=== $s ==="; bash "$s" || true; done
    sudo darwin-rebuild switch --flake .

# Show drift between binaries currently on PATH and the versions pinned
# in the flake. Useful when a CLI prints "newer version available".
drift:
    @for b in amp opencode droid codex gemini pi omp; do \
        printf '%-10s %s\n' "$b" "$(readlink -f ~/.nix-profile/bin/$b 2>/dev/null | sed -E 's|.*-([0-9][^/]*)/bin.*|\1|')"; \
    done

# Run the full check suite (unit + integration + system eval).
check:
    nix build --no-link \
        '.#darwinConfigurations.f.system' \
        '.#checks.aarch64-darwin.unit-overlay' \
        '.#checks.aarch64-darwin.unit-skill-router' \
        '.#checks.aarch64-darwin.integration-configurations-eval'

# Run the skill-router bun suite (spawn-seam gate) offline via the Nix sandbox.
test-router:
    nix build --no-link --print-build-logs \
        '.#checks.aarch64-darwin.unit-skill-router'

# Tier 2: read back the LIVE macOS state and confirm it matches what the
# config declares. Run after `just switch`. Non-hermetic, so it is NOT part of
# `nix flake check` (which only proves the config declares the right values).
verify-macos: _no-sudo
    bash scripts/verify-macos-settings.sh

# Garbage-collect old generations older than 30 days.
gc:
    sudo nix-collect-garbage --delete-older-than 30d
    nix-collect-garbage --delete-older-than 30d
