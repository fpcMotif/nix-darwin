# Reproducible dev environments and a cross-platform purity gate

Status: accepted

We keep developer environments reproducible across the active Mac and staged Linux hosts without risking Darwin store corruption or platform leaks:
1. Replace inline `auto-optimise-store` ([NixOS/nix#7273](https://github.com/NixOS/nix/issues/7273)) with scheduled `nix.optimise.automatic`, and keep `nix-direnv` outputs and derivations across GC.
2. Expose all dev environments from the flake: `devShells.<system>.default`, `templates.dev-shell`, and `packages.<linux-system>.dev-container`.
3. Keep the macOS Linux builder VM (`martin.linuxBuilder.enable`) off by default.
4. Gate macOS-only paths in `modules/home/` behind `pkgs.stdenv.isDarwin`, checked by `tests/integration/home-linux-purity-test.nix`.

## Considered options

- **Keep `nix.settings.auto-optimise-store = true` on macOS.** Rejected: inline hardlinking during builds triggers known Darwin store corruption bugs.
- **Enable `martin.linuxBuilder` by default on Darwin.** Rejected: runs a background QEMU VM and downloads a builder image on first switch even when unused.
- **Wait until a physical Linux host is active to clean up Darwin paths in `modules/home/`.** Rejected: unguarded `/Applications`, `~/Library`, `pbcopy`, and `darwin-rebuild` references accumulate silently unless CI fails at eval time.

## Consequences and trade-offs

- Keeping build outputs and derivations for `nix-direnv` increases Nix store disk usage between the twice-daily 14-day garbage-collection runs.
- Building `packages.aarch64-linux.dev-container` or the UTM guest locally on the Mac requires enabling `martin.linuxBuilder.enable` or using a Linux host.
- **Reversal trigger:** If upstream Nix fixes [NixOS/nix#7273](https://github.com/NixOS/nix/issues/7273) on APFS, inline store optimization can replace the scheduled launchd job.
