# Google Drive and Raycast are GUI-managed, not Nix-managed

Status: accepted

Google Drive and Raycast conflict with `/nix/store` for the same reasons as Dropbox (ADR-0005), BetterMouse (ADR-0011), and BetterDisplay (ADR-0012). Both apps run continuous built-in auto-updaters that write in place. Google serves `GoogleDrive.dmg` from an unversioned rolling URL whose upstream updates repeatedly broke `just switch`. Google Drive registers File Provider extensions and `SMAppService` helpers in `/Applications`, and Raycast requires persistent Accessibility permissions and runtime extension state. We removed `pkgs/google-drive.nix`, `pkgs/raycast.nix`, and their updaters; the user installs and updates both apps through their macOS GUI installers.

## Considered options

- **Keep refreshing the rolling `GoogleDrive.dmg` hash and versioned `Raycast.dmg` pin in Nix.** Rejected: Google Drive's unversioned DMG breaks system builds whenever Google republishes it, and both self-updaters fight read-only store symlinks.
- **Install and update Google Drive and Raycast natively via their GUI installers (chosen).** Eliminates rolling-URL build breakages and preserves macOS File Provider and Accessibility registrations.

## Consequences and trade-offs

- The operator installs Google Drive and Raycast manually on a new Mac rather than through `darwin-rebuild switch`.
- Rolling-pin maintenance covers only font archives (`pkgs/sf-mono.nix`) that have no self-updater or system extension.
- **Reversal trigger:** Revisit if a pure CLI or declarative tool replaces Raycast or Google Drive without privileged helpers or rolling URLs.
