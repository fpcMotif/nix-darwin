# Tests

Lightweight test suite for this flake. Wired into `flake.nix` as
`checks.<system>` so `nix flake check` runs everything.

## Layout

```
tests/
|-- default.nix                              # entry point, builds the check set
|-- lib/
|   `-- assertions.nix                       # tiny assertTest / testSuite helpers
|-- unit/
|   |-- mksystem-test.nix                    # lib/mkSystem.nix shape and current host contract
|   |-- overlay-test.nix                     # pkgs/default.nix overlay, attrs, metadata
|   |-- format-test.nix                      # formatter wiring and nixpkgs-fmt check
|   `-- skill-router-test.nix                # runs the tools/skill-router bun suite offline (spawn-seam gate)
`-- integration/
    `-- configurations-eval-test.nix         # current darwin/nixos configs and module outputs
```

## Running locally

```bash
# All checks for the current system
nix flake check --print-build-logs

# A single check
nix build .#checks.aarch64-darwin.unit-mksystem --no-link
nix build .#checks.aarch64-darwin.unit-overlay --no-link
nix build .#checks.aarch64-darwin.unit-format --no-link
nix build .#checks.aarch64-darwin.unit-skill-router --no-link
nix build .#checks.aarch64-darwin.integration-configurations-eval --no-link
nix build .#checks.aarch64-darwin.smoke-build-common --no-link
nix build .#checks.aarch64-darwin.smoke-build-oh-my-pi --no-link
nix build .#checks.aarch64-darwin.smoke-build-toolchain --no-link

# List available checks for a system
nix eval --json '.#checks.aarch64-darwin' --apply 'builtins.attrNames'
```

Replace `aarch64-darwin` with `x86_64-linux` on Linux hosts.

## What each test does

| Test                                | What it validates |
|-------------------------------------|-------------------|
| `smoke`                             | Test infrastructure itself builds. |
| `smoke-build-common`                | Common package smoke coverage, currently `mgrep --version`. |
| `smoke-build-oh-my-pi`              | Darwin-only Oh My Pi package exposes an executable `omp` wrapper and skips on Linux. |
| `smoke-build-toolchain`             | Required Prek, Oxlint/Oxfmt, Tsgolint, Tsgo, Uv, and Ruff commands exist, plus the shipped canary Bun (and its `bunx` symlink) on Darwin. |
| `unit-mksystem`                     | `lib/mkSystem.nix` shape plus current user, host platform, Home Manager, host module, and skill-target wiring. |
| `unit-overlay`                      | `pkgs/default.nix` is a valid overlay and exposes the expected `pkgs.martin.*` attributes, descriptions, and CLI main programs. Darwin-only package evaluation is skipped on Linux. |
| `unit-format`                       | `formatter.<system>` is configured as `nixpkgs-fmt`, evaluates, and all flake Nix files are formatted. |
| `unit-skill-router`                 | Runs the `tools/skill-router` bun suite (`test/subprocess-gating.test.ts`) offline inside the Nix sandbox. Pins the spawn seam so `discover`/`load` never reach a real `bunx @tanstack/intent` subprocess unless package scope is explicitly requested (ADR-0006); the bundled `bunfig.toml` preload (`SKILL_ROUTER_NO_REAL_SPAWN`) makes any real spawn fail loud and offline. Uses the shipped canary Bun on Darwin, stock `pkgs.bun` on Linux. |
| `integration-configurations-eval`   | The flake's Darwin/NixOS configs evaluate and keep expected user, host, pure-Nix dotfile, activation dry-run, required/forbidden toolchain, WSL, and agent-skills settings. |
| `integration-darwin-settings`       | Darwin-only. Exact-value assertions for every `system.defaults` key plus sudo Touch ID, firewall, pmset power management, skhd hotkeys, and the Gatekeeper guard; font-bundle membership + count; Rime/Squirrel and BetterMouse/BetterDisplay agent wiring. No-op skip on Linux. |

Real-machine verification (Tier 2) lives outside the Nix checks in
`scripts/verify-macos-settings.sh` (run via `just verify-macos`); the deferred
VM tier (Tier 3) is designed in `docs/design/darwin-activation-vm-harness.md`.
The overall strategy is recorded in
`docs/adr/0004-macos-settings-testing-strategy.md`.

## CI

`.github/workflows/build.yml` runs `nix flake check` on `macos-14` and
`ubuntu-latest`, then builds each system configuration in parallel jobs. The
macOS check path also builds the package smoke checks exposed from
`tests/default.nix`. Because `unit-skill-router` is a regular check, the
`tools/skill-router` bun suite now runs on both CI runners with no extra step —
it is the only automated gate on the spawn seam (previously `bun test` ran only
by hand). Run it locally with `just test-router`.
