# BetterDisplay is GUI-managed, not Nix-managed

Status: accepted

BetterDisplay shares the same macOS permission and updater mechanics as BetterMouse (ADR-0011). It self-updates in place via Sparkle, requires Screen Recording and Accessibility grants (which stamp `com.apple.macl` on store paths), and owns runtime display presets. On the active Mac, `.betterdisplay.src` still pointed at a store path after `/Applications/BetterDisplay.app` disappeared, so the LaunchAgent ran `open -g` against a missing bundle. We removed `modules/darwin/display.nix`, `pkgs.betterdisplay`, and its LaunchAgent; the user installs and updates BetterDisplay through its own GUI.

## Considered options

- **Fix the marker check in `modules/darwin/display.nix` and keep Nix-managing BetterDisplay.** Rejected: fixing the missing-bundle check still leaves Sparkle fighting the Nix pin and `com.apple.macl` threatening store garbage collection.
- **Install BetterDisplay manually in `/Applications` and let Sparkle update it (chosen).** Keeps Screen Recording grants attached to one stable `/Applications/BetterDisplay.app` bundle.

## Consequences and trade-offs

- Fresh-machine setup requires downloading BetterDisplay from `betterdisplay.pro` and enabling "Launch at login" inside its preferences.
- `darwin-betterdisplay-not-nix-managed` and `darwin-settings-no-betterdisplay-agent` fail CI if a Nix derivation or LaunchAgent for BetterDisplay returns.
- **Reversal trigger:** Revisit only if macOS decouples TCC Screen Recording grants and `com.apple.macl` from the bundle's store path (ADR-0011).
