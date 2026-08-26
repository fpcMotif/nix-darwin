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

# Refuse to build while unresolved merge/stash conflict markers sit in the
# tree — darwin-rebuild would otherwise die mid-eval with an opaque nix
# syntax error pointing at the '<<<<<<<' line.
_no-conflicts:
    @conflicted="$(git grep -lE '^(<<<<<<< |[|][|][|][|][|][|][|] |=======$|>>>>>>> )' -- '*.nix' flake.lock 2>/dev/null || true)"; \
    if [ -n "$conflicted" ]; then \
        echo 'just: unresolved conflict markers in:' >&2; \
        echo "$conflicted" >&2; \
        echo 'fix: resolve the <<<<<<< blocks, git add the files; if an autostash conflicted, git stash drop afterwards.' >&2; \
        exit 1; \
    fi

# Refuse to build while macOS has booted the nix jobs out of launchd, and
# repair them in place. Background Task Management (System Settings > General >
# Login Items & Extensions, plus any "cleaner" utility that walks that list)
# drops every org.nixos.* item at once — the plists and the store paths they
# point at stay intact, only the launchd jobs are gone. Two of them hurt:
#
#   nix-daemon       every nix command dies with
#                    "cannot connect to socket at '/nix/var/nix/daemon-socket/socket'"
#   activate-system  never recreates /run/current-system, and macOS wipes /run
#                    on every boot — so /run/current-system/sw/bin disappears and
#                    `nix` and `darwin-rebuild` silently fall off PATH entirely.
#
# The daemon's socket *file* outlives the daemon, so probe it by connecting,
# not with -S. Connect with `nc -U -w2`, never `nc -zU`: on macOS `-z` is
# TCP/UDP scan mode and is silently a no-op against a -U socket, so `nc -zU`
# exits non-zero even against a healthy daemon. That turned this preflight into
# an unconditional sudo password prompt on every build which then always
# reported "still down", because the verify loop reused the same broken probe.
#
# Only sudos when something is actually missing. Bootstrapping activate-system
# re-runs the activation script (RunAtLoad), which is what restores
# /run/current-system — exactly what a normal boot would have done.
_daemon:
    @up() { nc -U -w 2 /nix/var/nix/daemon-socket/socket </dev/null >/dev/null 2>&1; }; \
    loaded() { launchctl print "system/org.nixos.$1" >/dev/null 2>&1; }; \
    revive() { \
        sudo launchctl enable "system/org.nixos.$1" 2>/dev/null || true; \
        sudo launchctl bootstrap system "/Library/LaunchDaemons/org.nixos.$1.plist" 2>/dev/null || true; \
    }; \
    gone=''; \
    up || gone="$gone nix-daemon"; \
    { [ -e /run/current-system ] && loaded activate-system; } || gone="$gone activate-system"; \
    for j in nix-gc nix-optimise nix-auto-switch; do \
        loaded "$j" || gone="$gone $j"; \
    done; \
    [ -n "$gone" ] || exit 0; \
    echo "just: macOS booted these nix launchd jobs out:$gone" >&2; \
    echo 'just: re-bootstrapping them, needs sudo.' >&2; \
    for j in $gone; do revive "$j"; done; \
    for _ in 1 2 3 4 5 6 7 8 9 10; do \
        if up && [ -e /run/current-system ]; then \
            echo 'just: nix launchd jobs restored.' >&2; exit 0; \
        fi; \
        sleep 1; \
    done; \
    echo 'just: still broken after bootstrap. Background Task Management is holding a' >&2; \
    echo '  "disallowed" approval for these items, and only the GUI clears that:' >&2; \
    echo '  System Settings > General > Login Items & Extensions > Allow in the Background' >&2; \
    echo '  enable every entry pointing at /Library/LaunchDaemons/org.nixos.*.plist' >&2; \
    echo '  (they show up as "sh", plus "martin-auto-switch").' >&2; \
    echo 'See PANIC.md section 6.' >&2; \
    exit 1

# Default: print available recipes.
default: _no-sudo
    @just --list

# Bring the nix daemon back after macOS boots it out of launchd. Safe to run
# any time — a no-op when the daemon is already answering.
fix-daemon: _no-sudo _daemon
    @echo 'fix-daemon: nix-daemon is answering on /nix/var/nix/daemon-socket/socket.'

# Re-prefetch every pin whose upstream URL carries no version. Those assets are
# republished in place (bun's force-pushed `canary` tag, Apple's SF-Mono.dmg,
# Google's GoogleDrive.dmg), so their recorded sha256 goes stale on upstream's
# schedule and the stale hash fails the *whole* system build, not just that
# package. tests/unit/rolling-pins-test.sh keeps this set honest.
refresh-rolling: _no-sudo _daemon
    @for s in update-bun-canary update-google-drive update-sf-mono; do \
        echo "=== $s ==="; bash "scripts/$s.sh" || true; \
    done

# Shared failure hint. A fixed-output hash mismatch is almost always a rolling
# pin drifting rather than anything wrong with the working tree, and the raw
# nix output buries that under a wall of "Cannot build" cascades.
_drift-hint:
    @echo '' >&2; \
    echo 'just: if the failure above is "hash mismatch in fixed-output derivation",' >&2; \
    echo '  a rolling pin drifted — upstream republished the same URL. Recover with:' >&2; \
    echo '      just refresh-rolling' >&2; \
    echo '  then re-run. See PANIC.md section 8.' >&2

# Build (no activate) the darwin system from the working tree. Use this
# to dry-run a change before committing to a switch.
build: _no-sudo _daemon _no-conflicts
    @darwin-rebuild build --flake . || { just _drift-hint; exit 1; }

# Activate the working-tree configuration (system + home-manager).
switch: _no-sudo _daemon _no-conflicts
    @sudo darwin-rebuild switch --flake . || { just _drift-hint; exit 1; }

# Pull latest origin/main (rebase + autostash). Version/hash bumps that raced
# an auto-update run resolve themselves to the newer side via the pkgnix
# merge driver (scripts/git-merge-pkgnix.sh); anything structural stops with
# markers, which _no-conflicts then refuses to build.
sync: _no-sudo
    git pull --rebase --autostash
    @if [ -n "$(git ls-files -u)" ]; then \
        echo 'sync: conflicts remain — resolve them, git add, then git stash drop the kept autostash. git status shows the files.' >&2; \
        exit 1; \
    fi
    @just _no-conflicts
    @echo 'sync: clean.'

# Bump every flake input to its latest revision, then activate.
update-and-switch: _no-sudo _daemon
    nix flake update
    sudo darwin-rebuild switch --flake .

# Run every scripts/update-*.sh updater, then activate. This is what the
# nightly auto-update GitHub workflow does, but on-demand. Forces the full
# bump: an explicit human invocation wants fresh nixpkgs too (issue #336).
bump-and-switch: _no-sudo _daemon
    export AU_FORCE_FULL_BUMP=1
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
        '.#checks.aarch64-darwin.unit-justfile' \
        '.#checks.aarch64-darwin.unit-claude-md' \
        '.#checks.aarch64-darwin.unit-auto-update' \
        '.#checks.aarch64-darwin.unit-rolling-pins' \
        '.#checks.aarch64-darwin.unit-skill-router' \
        '.#checks.aarch64-darwin.unit-skill-hygiene' \
        '.#checks.aarch64-darwin.integration-configurations-eval'

# Run the skill-router bun suite (spawn-seam gate) offline via the Nix sandbox.
test-router:
    nix build --no-link --print-build-logs \
        '.#checks.aarch64-darwin.unit-skill-router'

# Lint Nix sources: statix (antipatterns) + deadnix (dead code). Advisory —
# not yet a CI gate (see ARCHITECTURE.md). Tools come pinned from the repo
# dev shell; statix.toml scopes both away from references/.
lint:
    nix develop --command statix check .
    nix develop --command deadnix --fail . --exclude ./references

# Build the reproducible OCI dev container for Apple Silicon Linux runtimes
# (OrbStack/Docker/UTM guests). Requires an aarch64-linux builder — enable
# martin.linuxBuilder in hosts/darwin/default.nix first.
dev-container:
    nix build '.#packages.aarch64-linux.dev-container'
    @echo "Load with: docker load < result"

# Tier 2: read back the LIVE macOS state and confirm it matches what the
# config declares. Run after `just switch`. Non-hermetic, so it is NOT part of
# `nix flake check` (which only proves the config declares the right values).
verify-macos: _no-sudo
    bash scripts/verify-macos-settings.sh

# Tier 2: read back the LIVE agent-skill surfaces and confirm every id is
# advertised to Claude Code exactly once while the other eight picker dirs keep
# the full bundle. Run after `just switch`. Non-hermetic (reads ~/.claude and
# the plugin cache), so it is NOT part of `nix flake check`.
verify-skills: _no-sudo
    bash scripts/verify-agent-skills.sh

# Garbage-collect old generations older than 30 days.
gc:
    sudo nix-collect-garbage --delete-older-than 30d
    nix-collect-garbage --delete-older-than 30d
