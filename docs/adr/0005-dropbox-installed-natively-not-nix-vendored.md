# Install Dropbox natively, not as a Nix-vendored app

Status: accepted

The repo carried an opt-in Nix scaffold for Dropbox: a `pkgs/dropbox.nix` derivation that fetched the official `.dmg` and copied `Dropbox.app` into the read-only store, a `martin.backgroundServices.dropbox` module exposing `installClient` / `disableBackgroundUpdaters`, host wiring, an `update-dropbox.sh` bumper, and supporting tests. `installClient` was always `false`, so it never actually installed Dropbox — it was a parked scaffold.

We removed it in full and decided Dropbox is installed **by hand, the normal macOS way**: download the installer from dropbox.com in a browser and run the GUI installer so the app lands in `/Applications`, then let Dropbox self-update from then on. It is **not** Nix-vendored, **not** a Homebrew cask, and has **no** managed install path — there is deliberately nothing about Dropbox in the flake to `darwin-rebuild`. The default policy elsewhere is "pure Nix first" (see `ARCHITECTURE.md`); Dropbox is a deliberate exception.

## Why the Nix way loses for Dropbox specifically

- **Self-update vs. immutable store.** Dropbox rewrites its own `.app` bundle in place and the `DropboxMacUpdate` helper cannot be removed without removing the app. Against a read-only store symlink the update fails and nags, or Dropbox silently installs a second copy under `~/Library`, so the running client diverges from the pinned Nix build. This is the same failure class already seen with the Nix-managed Zed bundle.
- **Forced deprecation.** Dropbox's server can hard-deprecate old clients ("update to keep syncing"). A hash-pinned build then stops working until someone manually bumps it — a maintenance treadmill for software designed to update itself silently.
- **File Provider + privileged helper.** Modern Dropbox registers a macOS File Provider extension and installs `com.getdropbox.dropbox.UpdaterPrivilegedHelper` via `SMAppService`, which expect a stable, code-signed app in `/Applications` — not `/Applications/Nix Apps/Dropbox.app` whose store path changes hash on every bump. Login-item-at-boot registration breaks for the same reason. Suppressing that helper (as `disableBackgroundUpdaters` did) degrades the very mechanism Dropbox needs.
- **Illusory reproducibility.** The `fetchurl` pinned a specific `edge.dropboxstatic.com` DMG. Dropbox rotates old build URLs, so once a pinned version 404s upstream a clean rebuild cannot fetch the source at all until the hash is bumped.

Any one of these is disqualifying; there are four.

## Consequences

- `pkgs/dropbox.nix`, `scripts/update-dropbox.sh`, the `martin.backgroundServices.dropbox` options, the host wiring, and the Dropbox test/verify assertions were deleted. `martin.backgroundServices` now only manages CleanMyMac.
- Removing the launchd-suppression entries lets the baseline activation's reversible state auto-`launchctl enable` the previously-disabled `com.getdropbox.dropbox.*` labels, so a natively-installed Dropbox updates normally with no manual step.
- Re-adding any Nix Dropbox scaffold is a deliberate new decision, not a gap to fill — treat its reappearance as a regression.
