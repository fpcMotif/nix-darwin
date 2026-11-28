# macOS settings are tested in tiers: hermetic eval, then opt-in live read-back

Status: accepted

Nix evaluation cannot prove that imperative macOS settings (`defaults`, `pmset`, `launchctl`, Gatekeeper) took effect on the live machine. Live-machine checks cannot run inside the hermetic `nix flake check` sandbox. We split verification into two active tiers and defer a third VM tier:
1. **Tier 1 (`tests/integration/darwin-settings-test.nix`):** runs in CI and restates expected `system.defaults` values, keysets, and `postActivation` commands.
2. **Tier 2 (`scripts/verify-macos-settings.sh`):** runs after `just switch` via `just verify-macos` to read live macOS state.
3. **Tier 3 (`docs/design/darwin-activation-vm-harness.md`):** defines a macOS VM activation harness, deferred today.

## Considered options

- **Derive Tier 1 test expectations by importing `modules/darwin/defaults.nix`.** Rejected: a test that imports its own implementation catches only syntax errors, never a wrong value.
- **Run live `defaults read` checks inside `nix flake check`.** Rejected: the Nix sandbox and Linux CI runners cannot access the macOS preference daemon.
- **Stand up a nested-virtualization macOS VM runner in CI (Tier 3).** Rejected for now: hosted macOS runners lack reliable nested virtualization, and self-hosting for one Mac costs too much.

## Consequences and trade-offs

- Changing any managed macOS default in `modules/darwin/defaults.nix` requires updating the matching literal and keyset in `tests/integration/darwin-settings-test.nix`.
- Imperative activation failures appear only when the operator runs `just verify-macos` after a switch, not in CI.
- **Reversal trigger:** When CI or local Tart runners support fast, deterministic macOS guest VMs, wire Tier 3 from `docs/design/darwin-activation-vm-harness.md`.
