# Reproducible dev environments and a cross-platform purity gate

Status: accepted

This ADR records four related decisions that tighten the repo around its core
contract — *every setting Nix manages must be reproducible from the flake* —
while keeping the active Mac (Apple Silicon, `darwinConfigurations.f`) first
and the staged Linux/WSL targets honest.

## 1. Scheduled store optimisation instead of `auto-optimise-store`

`nix.settings.auto-optimise-store = true` deduplicates inline during builds,
but it has a long-standing store-corruption bug on macOS
(<https://github.com/NixOS/nix/issues/7273>). On the platform we actually run,
that trades disk savings for the risk of an unrecoverable store. It was
replaced with `nix.optimise.automatic` — the same hardlink deduplication, run
as a scheduled launchd job shortly after the weekly GC so it only touches what
survived collection.

`keep-outputs`/`keep-derivations` flipped from `false` to `true` at the same
time: nix-direnv (already enabled in `modules/home/zsh.nix`) documents both as
required so direnv-pinned dev shells survive garbage collection and keep
working offline. The weekly `--delete-older-than 14d` GC still bounds growth.

## 2. Dev environments are flake outputs, not ambient tools

- `devShells.<system>.default` is the repo's own maintainer shell (just,
  nixpkgs-fmt, statix, deadnix, shellcheck), entered via `nix develop` or the
  checked-in root `.envrc`.
- `templates.dev-shell` (`nix flake init -t …#dev-shell`) seeds per-project
  pinned shells with the same direnv wiring, portable across the Mac, future
  Linux/WSL hosts, and containers.
- `packages.<linux-system>.dev-container` builds an OCI dev image with
  `dockerTools.buildLayeredImage` from the same pinned nixpkgs — no Dockerfile,
  no `apt-get`/`curl | sh` drift, content-addressed tag instead of `latest`.

## 3. The Linux builder is an explicit, off-by-default module

`martin.linuxBuilder.enable` (modules/darwin/linux-builder.nix) wraps
nix-darwin's `nix.linux-builder` so the M-series Mac can build aarch64-linux
closures locally — the UTM guest toplevel and the dev container image. It
stays **disabled by default** because it runs a background QEMU VM and its
first activation must download the builder image; enabling it is a deliberate
per-host choice, not baseline behavior. The builder is `ephemeral`, so its
state resets on restart and "restart the builder" is a complete repair.

## 4. macOS-only content may not leak into Linux closures

`modules/home` is shared by every host. Unguarded macOS paths
(`/Applications/...`, `~/Library/Application Support/...`) and macOS-only
tools (`pbcopy`, `ipconfig`, `darwin-rebuild`, `xcrun`, OrbStack) had leaked
into session variables, zsh config, and activation scripts that Linux hosts
would also receive. All such content is now gated behind
`pkgs.stdenv.isDarwin`, and `tests/integration/home-linux-purity-test.nix`
asserts — at eval time, against the merged option values of the Linux hosts —
that none of a known pattern list reappears. The check runs in CI on the
x86_64-linux builder; regressions fail the build, not a future Linux
bring-up.
