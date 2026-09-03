# Google Drive and Raycast are GUI-managed, not Nix-managed

Status: accepted

Date: 2026-09-03

Google Drive (`GoogleDrive.dmg` / `pkgs/google-drive.nix`) and Raycast (`Raycast.dmg` / `pkgs/raycast.nix`) are removed from the Nix flake. Both apps are installed and updated **directly through their native macOS GUI installers and self-updaters**.

## Why

The reasons from ADR 0005 (Dropbox), ADR 0011 (BetterMouse), and ADR 0012 (BetterDisplay) apply to Google Drive and Raycast:

- **Self-updater vs. immutable store**: Both Google Drive and Raycast contain aggressive built-in auto-updaters designed to run continuously and write in place. Stamping `/Applications/Nix Apps/` with read-only store symlinks causes self-updates to fail, nag the user, or silently spawn secondary unmanaged bundles in user caches.
- **Unversioned rolling URLs (Google Drive)**: Google serves `GoogleDrive.dmg` from a single rolling, unversioned URL without public release archives. Every time upstream silently updates the installer bytes, the fixed-output derivation hash broke the entire system build (`just switch`) until manually bumped.
- **System extensions, file providers, and permissions**: Google Drive registers file provider extensions, virtual drive mounts, and privileged helper services (`SMAppService`) that require stable bundle signatures in `/Applications`. Raycast requires global accessibility permissions, hotkey taps, and extension store management that are owned at user runtime.
- **Native GUI workflow**: Both applications are interactive GUI tools installed once via macOS DMG/GUI and maintained by their own release channels.

## Consequences

- `pkgs/google-drive.nix`, `pkgs/raycast.nix`, `scripts/update-google-drive.sh`, and `scripts/update-raycast.sh` are deleted.
- `pkgs.martin.google-drive` and `pkgs.martin.raycast` are removed from the overlay and Darwin host packages (`hosts/darwin/default.nix` and `modules/home/packages.nix`).
- `update-google-drive` is removed from `justfile` (`refresh-rolling`) and `.github/workflows/auto-update.yml`.
- Re-adding Nix derivations for Google Drive or Raycast is considered a regression.
