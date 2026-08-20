# BetterDisplay is GUI-managed, not Nix-managed

Status: accepted

Date: 2026-08-19

BetterDisplay was the last app left in `modules/darwin/display.nix` — the module that
survived the BetterMouse removal (ADR 0011) by being narrowed to BetterDisplay only.
It is now removed too. BetterDisplay is installed and updated **entirely through its
own GUI**, and the whole `martin.display` module is gone from the flake.

## Why

The reasoning from ADR 0011 applies to BetterDisplay unchanged — it is the same class
of app, distributed the same way:

- **Sparkle vs. the pin.** BetterDisplay self-updates. The module's `install_managed_app`
  had to `chmod -R u+w` the `/Applications` copy so version bumps could replace it, which
  is exactly the write access Sparkle needs to float the bundle off the pinned version.
  The re-copy guard compares the *source store path* marker, not installed content, so the
  drift is invisible to activation and every later `darwin-rebuild switch` is a no-op.
- **`com.apple.macl` poisons the store.** BetterDisplay wants Screen Recording (and
  Accessibility for some features). Granting those to a *store* path stamps a kernel
  xattr that makes the bundle undeletable even by root, which aborts `nix.gc` for the
  whole store. The `/Applications`-copy dance existed only to dodge this.
- **Per-display state is the app's, not ours.** Display presets, resolutions and
  brightness curves are runtime state BetterDisplay owns; Nix never had anything
  meaningful to declare about them.

Observed state on the machine at removal time, which is what prompted this: the pin was
`betterdisplay-4.3.4`, `/Applications/.betterdisplay.src` still pointed at that store path
from 30 Jul, `/Applications/BetterDisplay.app` **did not exist at all**, and the
`org.nix-community.home.betterdisplay` LaunchAgent was faithfully running
`open -g` against the missing bundle on every login. The Nix scaffolding had been
describing an app that wasn't there.

## Consequences

- `modules/darwin/display.nix` is deleted, along with its import in
  `modules/darwin/default.nix` and `display.enable = true` in `hosts/darwin/default.nix`.
  `pkgs.betterdisplay` leaves the closure, so `/Applications/Nix Apps/BetterDisplay.app`
  disappears with it.
- The `betterdisplay` LaunchAgent is removed by Home Manager on the next switch.
  BetterDisplay's own "Launch at login" setting is the replacement.
- The stale `/Applications/.betterdisplay.src` marker was removed by hand at the same
  time; nothing cleans it any more, since the module that dropped it is gone.
- Install BetterDisplay from <https://betterdisplay.pro> into `/Applications` and let
  Sparkle keep it current. Grant Screen Recording to that copy, not a store path.
- `darwin-betterdisplay-not-nix-managed` and `darwin-settings-no-betterdisplay-agent`
  guard the decision, mirroring the BetterMouse guards. `scripts/verify-macos-settings.sh`
  now fails if either agent reappears. Re-adding a Nix BetterDisplay scaffold is a
  deliberate new decision, not a gap to fill.
- The BetterMouse one-shot cleanups that lived in this module (removing
  `/Applications/.bettermouse.src` and the `.nix-seed-source` seed stamp) had already run
  on the machine, so they are dropped rather than rehomed.
