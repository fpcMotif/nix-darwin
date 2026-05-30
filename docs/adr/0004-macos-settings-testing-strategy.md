# macOS settings are tested in tiers: hermetic eval, then opt-in live read-back

The macOS state this flake manages is verified in two enforced tiers plus a
third that is designed but deliberately not wired.

**Tier 1 -- hermetic eval (`tests/integration/darwin-settings-test.nix`, in
`nix flake check`).** `modules/darwin/defaults.nix` is the source of truth; this
test independently RESTATES the committed values as a change-detector. Every
declarative `system.defaults` key is asserted against its exact expected value
(one `assertTest` per key), *plus* a per-domain closure guard
(`darwin-settings-<domain>-keyset`) asserting the config manages exactly the
expected key set, *plus* a `CustomUserPreferences` domain-set guard. So both
directions of drift fail CI loudly: a flipped value (`should be X but is Y`) and
a key silently *added* to (or removed from) the module without being mirrored
here -- the latter being exactly where an automated `autoresearch` commit could
inject an unmanaged setting. We deliberately do NOT derive the expectations from
the module (e.g. import the same attrset): a derived test can only catch
evaluation errors, never a wrong-but-consistent value, so independent
restatement is the whole point. macOS security posture (Gatekeeper/quarantine,
`LaunchServices.LSQuarantine`, the application firewall, disk-image
verification) lives in this file too -- one fact, one file. The imperative
activation layer (pmset, the Squirrel symlink) cannot be checked for effect at
eval time, so it is asserted by string-matching the rendered
`system.activationScripts.postActivation.text` -- the most eval can see. This
tier is pure and runs on every push; on the NixOS hosts it is a no-op skip
because macOS settings have no meaning there. Note that nix-darwin `apply`s some
options (e.g. `finder.NewWindowTarget` stores the friendly `"Home"` as the plist
code `"PfHm"`), so the expected values are the evaluated forms that actually
land in the plist, not always the source literals.

**Tier 2 -- live read-back (`scripts/verify-macos-settings.sh`, opt-in, NOT in
`nix flake check`).** Run after `just switch` via `just verify-macos`. It reads
the activated machine -- `defaults read`, `pmset -g custom`, `spctl --status`,
`socketfilterfw`, the Squirrel symlink, `launchctl` -- and confirms the
imperative layer and a representative slice of declarative defaults actually
took. It is excluded from `nix flake check` because it inspects mutable machine
state and is non-hermetic. It reports PASS/FAIL/SKIP and only fails on real
drift; settings that are inapplicable on the current hardware (the Intel-era
`pmset hibernatemode`/`standbydelay*` keys, which Apple Silicon ignores) are
skipped, not failed.

**Tier 3 -- darwin activation VM (designed, deferred).** A full
build-and-activate harness in a VM would be the only way to prove the reversible
launchd/marker engine's *effects* end-to-end. It is documented in
`docs/design/darwin-activation-vm-harness.md` but intentionally not wired into
the checks: darwin activation cannot run inside a Linux `nixosTest` VM, and a
macOS runner with nested virtualization is not justified for a single host.

Intentionally untested: TCC-protected preference domains (`com.apple.Safari`,
`com.apple.universalaccess`, `com.apple.AdLib`) whose `defaults write` aborts
activation without Full Disk Access, and the dormant Homebrew scaffold. The
`autoresearch` eval-speed loop optimizes the *other* integration test file
(`configurations-eval-test.nix`); the settings spec -- including security
posture -- lives in its own file so the loop cannot reshuffle or revert these
assertions, and the closure guards make a silent re-introduction fail there.
