# BetterMouse is GUI-managed, not Nix-managed

Status: accepted

Date: 2026-08-17

The repo carried a full Nix ownership stack for BetterMouse: a `pkgs/bettermouse.nix` derivation fetching the upstream `.zip`, a `martin.mouseDisplay` module that copied the app into `/Applications` and seeded a binary-plist profile, a `bettermouse` LaunchAgent, a `scripts/update-bettermouse.sh` bumper, and test assertions covering all of it.

We removed it in full. BetterMouse is now installed and updated **entirely through its own GUI** — the app self-updates via Sparkle, and there is deliberately nothing about BetterMouse in the flake to `darwin-rebuild`. The default policy elsewhere is "pure Nix first" (see `ARCHITECTURE.md`); BetterMouse joins Dropbox (ADR 0005) as a deliberate exception.

## What actually went wrong

The pin stopped describing reality, silently, and nothing in the activation path could detect it.

Forensics from the machine on 2026-08-17:

| Fact | Value |
| --- | --- |
| Pinned in `pkgs/bettermouse.nix` | `1.6.8904` |
| `/Applications/.bettermouse.src` marker | `/nix/store/hxbffr3xq561p50vxr7vsji2x8xvsddq-bettermouse-1.6.8904` |
| `/Applications/BetterMouse.app` `CFBundleVersion` | **8905** |
| `/Applications/Nix Apps/BetterMouse.app` `CFBundleVersion` | 8904 |
| Process actually holding the event tap | `/Applications/Nix Apps/BetterMouse.app` |
| LaunchAgent `ProgramArguments` | `open -g /Applications/BetterMouse.app` |
| `SUEnableAutomaticChecks` / `SUAutomaticallyUpdate` | `1` / `1` |

Three independent defects compounded:

**1. The module made the app writable, so Sparkle could rewrite it.** `install_managed_app` ran `chmod -R u+w "$dst"` on the `/Applications` copy — necessary so a later version bump could replace it, but it also handed Sparkle exactly the write access it needed to self-update the bundle in place, from 8904 to 8905, outside Nix.

**2. The drift was undetectable by design.** The re-copy guard was:

```sh
[ ! -e "$dst" ] || [ "$(readlink "$marker" 2>/dev/null)" != "$pkg" ]
```

The marker tracks the *source store path*, not the *installed content*. After Sparkle rewrote the bundle, the marker still pointed at the 8904 store path and `$dst` still existed, so the condition was false and activation skipped the re-copy. Every subsequent `darwin-rebuild switch` was a no-op against a bundle that no longer matched the pin.

**3. `environment.systemPackages` published a second copy that defeated the store-path workaround.** The module's central comment explains that granting Accessibility / Input-Monitoring to a *store* path stamps a kernel `com.apple.macl` xattr that makes the bundle undeletable even by root, aborting `nix.gc` for the whole store — which is precisely why the app is copied to `/Applications` first. But listing the package in `environment.systemPackages` also published `/Applications/Nix Apps/BetterMouse.app`. Two bundles then shared bundle id `com.naotanhaocan.BetterMouse`, LaunchServices resolved `open -g /Applications/BetterMouse.app` to the store-backed copy, that copy is what the user granted Accessibility to, and `com.apple.macl` was confirmed present on it. The workaround was defeated by the module's own package list.

## Why the Nix way loses for BetterMouse specifically

- **Self-update vs. immutable store.** BetterMouse ships Sparkle with automatic checks and automatic install both on by default. Any writable copy will be rewritten out from under the pin; the only alternative is disabling the updater, which means hand-bumping a paid app that is designed to keep itself current.
- **Accessibility grants are path- and signature-bound.** BetterMouse is an event-tap app: it is useless without Accessibility and Input Monitoring. Those grants attach to a specific bundle path, and every version bump moves the store path, so the grant needs re-approving on a schedule Nix controls rather than the user.
- **`com.apple.macl` poisons the store.** Granting the permission the app requires stamps an xattr that breaks garbage collection for the entire store. The `/Applications`-copy workaround exists solely to dodge this, and it is one stray `environment.systemPackages` entry away from failing.
- **No stable upstream release channel.** There are no GitHub releases; `update-bettermouse.sh` scraped a WordPress RSS feed that mixes BetterMouse and thePadToo posts, and had already needed one fix for exactly that.

Any one of these is disqualifying; there are four.

## Consequences

- `pkgs/bettermouse.nix`, `scripts/update-bettermouse.sh`, and `modules/darwin/mouse-display.nix` were deleted. `martin.mouseDisplay` was narrowed to `martin.display`, in `modules/darwin/display.nix`, which now manages BetterDisplay only.
- `/Applications/BetterMouse.app` is **intentionally left on disk**. It is the GUI-managed install now, and deleting it would take the user's Accessibility and Input-Monitoring grants with it. Activation removes only the stale `/Applications/.bettermouse.src` marker and the `~/Library/Application Support/BetterMouse/.nix-seed-source` stamp; `bm_cfg.plist` stays, since BetterMouse owns that file at runtime.
- `/Applications/Nix Apps/BetterMouse.app` disappears once the package leaves the closure. It carries `com.apple.macl`, so if a GC or activation ever fails to remove it, clear the xattr first: `sudo xattr -rc "/Applications/Nix Apps/BetterMouse.app"`.
- Sparkle is deliberately left **enabled**. Updating BetterMouse is now the app's own job, from its GUI.
- `darwin-settings-no-bettermouse-agent` and `darwin-bettermouse-not-nix-managed` guard the decision. Re-adding a Nix BetterMouse scaffold is a deliberate new decision, not a gap to fill — treat its reappearance as a regression.

## Unrelated finding, fixed alongside

`com.apple.mouse.doubleClickThreshold` was found at `0.15` — the fast extreme of the System Settings slider, against a macOS default of `0.5`. At that value a double-click must complete within 150 ms or the OS delivers two separate single clicks, which is what prompted the original "clicks don't feel right" investigation. It was not owned by any module. It is now pinned to `0.5` in `modules/darwin/defaults.nix` under `CustomUserPreferences.NSGlobalDomain`, with a matching entry in the settings spec table.
