# Install Dropbox natively, not as a Nix-vendored app

Status: accepted

Dropbox rewrites its own `.app` bundle in place and enforces server-side client deprecation. It registers macOS File Provider extensions and `SMAppService` helpers that require `/Applications/Dropbox.app`, and it rotates download URLs. We removed `pkgs/dropbox.nix`, its updater, and `martin.backgroundServices.dropbox`. The user installs and updates Dropbox natively through its macOS GUI installer, as an exception in `AGENTS.md`.

## Considered options

- **Symlink or copy a Nix-vendored `Dropbox.app` from `/nix/store`.** Rejected: the read-only store breaks `DropboxMacUpdate`, new store hashes break File Provider registration, and rotated DMG URLs break rebuilds.
- **Manage Dropbox through a Homebrew cask.** Rejected: Homebrew stays off by default, and Dropbox's own updater already manages the bundle after installation.
- **Install and update Dropbox natively outside Nix (chosen).** Matches how Dropbox's updater, File Provider extension, and privileged helper work on macOS.

## Consequences and trade-offs

- Fresh-machine setup requires downloading and installing Dropbox manually from `dropbox.com`; `darwin-rebuild switch` does not install it.
- Removing the launchd-suppression entries lets baseline activation re-enable `com.getdropbox.dropbox.*` helpers automatically.
- **Reversal trigger:** Revisit only if Dropbox ships a versioned archive that runs without self-updating or path-bound system extensions.
