# Tier 3 design: darwin activation VM harness (deferred)

Status: **designed, not wired.** This is the end-to-end tier described in
[ADR-0004](../adr/0004-macos-settings-testing-strategy.md). It is documented
here as real, buildable-on-paper work so it can be picked up later, but it is
deliberately absent from `flake.checks` — see "Why it is not wired" below.

## What it would prove that Tiers 1 and 2 cannot

- **Tier 1** (`tests/integration/darwin-settings-test.nix`) proves the config
  *declares* the right values and *emits* the right activation commands. It
  never runs activation.
- **Tier 2** (`scripts/verify-macos-settings.sh`) proves the values are present
  on *this already-activated machine*. It cannot run in CI, cannot start from a
  clean slate, and cannot prove that a *fresh* `darwin-rebuild switch` converges.

The gap both leave open is the **reversible launchd/marker engine**
(`modules/darwin/baseline-activation.nix`): the highest-risk imperative code,
whose correctness is "after a switch, then a config change, then another switch,
the `/var/db/nix-config` state file and the launchd disable/enable + path-marker
reconciliation end up in the right state." Only a build-activate-mutate-activate
loop on a throwaway system can assert that.

## Sketch

A darwin equivalent of `nixosTest`: boot a macOS guest, copy the flake in,
`darwin-rebuild switch`, then run the Tier 2 script as the in-VM assertion body.

```nix
# tests/integration/darwin-activation-vm.nix  (illustrative — do not import)
{ self, pkgs, ... }:
pkgs.testers.runDarwinActivation {        # hypothetical; no such upstream tester
  name = "darwin-activation-f";
  flake = self;
  hostAttr = "f";
  testScript = ''
    machine.succeed("darwin-rebuild switch --flake ${self}#f")
    machine.succeed("bash ${self}/scripts/verify-macos-settings.sh")

    # Reversibility: flip a managed toggle, re-switch, assert state file +
    # launchd disabled-set reconcile, then flip back and assert the inverse.
    machine.succeed("...mutate martin.backgroundServices...")
    machine.succeed("darwin-rebuild switch --flake ...")
    machine.succeed("launchctl print-disabled gui/$(id -u) | grep -q CleanMyMac")
  '';
}
```

Then, when wired (it is not):

```nix
# tests/default.nix
darwin-activation-vm = lib.optionalAttrs pkgs.stdenv.isDarwin
  (callTest ./integration/darwin-activation-vm.nix { });
```

## Why it is not wired

1. **No Linux path.** `nixosTest` boots a Linux guest under QEMU/KVM; darwin
   activation needs a macOS guest. There is no upstream `runDarwinActivation`.
2. **Nested virtualization.** A macOS guest requires a macOS host with nested
   virt (tart/UTM/Apple Virtualization). GitHub's `macos-14` runners do not
   reliably offer it, and self-hosting a Mac purely for this is not justified
   for a single-host config.
3. **Cost/benefit.** Tier 1 catches declaration drift on every push; Tier 2
   catches application drift on demand. The residual risk — fresh-machine
   convergence of the reversible engine — is low-frequency and observable on the
   real machine. The VM's marginal coverage does not pay for its infrastructure.

## Prerequisites to revive this

- An upstream or hand-rolled macOS-guest activation tester (tart-based runner).
- A dedicated macOS CI runner with nested virtualization.
- A reset-to-snapshot step so each run starts from a known-clean system.
