# BetterMouse is GUI-managed, not Nix-managed

Status: accepted

BetterMouse requires macOS Accessibility and Input Monitoring permissions and ships Sparkle auto-updates enabled by default. When Nix copied a writable `BetterMouse.app` to `/Applications` and listed the package in `environment.systemPackages`, three failures compounded. Sparkle updated `/Applications/BetterMouse.app` in place past the Nix pin (from build 8904 to 8905) without triggering the store-path marker check. LaunchServices launched the second copy under `/Applications/Nix Apps/BetterMouse.app`. macOS then stamped the kernel `com.apple.macl` xattr on that store bundle, which blocks `nix.gc` from deleting it. We removed `pkgs/bettermouse.nix`, its updater, and the BetterMouse LaunchAgent; the user manages BetterMouse through its own GUI (`AGENTS.md`).

## Considered options

- **Keep Nix-copying `BetterMouse.app` and disable Sparkle.** Rejected: requires scraping an unstable WordPress RSS feed and re-granting macOS Accessibility permissions whenever the bundle changes.
- **Symlink `BetterMouse.app` directly from `/nix/store`.** Rejected: granting Accessibility to a store path stamps `com.apple.macl` on the store bundle so even root cannot delete it.
- **Manage BetterMouse through its own GUI and Sparkle updater (chosen).** Preserves macOS Accessibility grants across updates and keeps `com.apple.macl` out of `/nix/store`.

## Consequences and trade-offs

- Nix leaves `/Applications/BetterMouse.app` and `bm_cfg.plist` unmanaged; the operator installs BetterMouse manually on a new Mac.
- If an old `/Applications/Nix Apps/BetterMouse.app` bundle blocks garbage collection, clear its xattr once with `sudo xattr -rc "/Applications/Nix Apps/BetterMouse.app"`.
- **Reversal trigger:** Revisit only if macOS TCC decouples Accessibility grants from mutable app paths and stops stamping `com.apple.macl` on store bundles.
