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
|   `-- format-test.nix                      # formatter wiring and nixpkgs-fmt check
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
nix build .#checks.aarch64-darwin.integration-configurations-eval --no-link
nix build .#checks.aarch64-darwin.smoke-build-common --no-link
nix build .#checks.aarch64-darwin.smoke-build-gemini --no-link
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
| `smoke-build-gemini`                | Darwin-only Gemini preview package path evaluates/builds on Darwin and skips on Linux. |
| `smoke-build-oh-my-pi`              | Darwin-only Oh My Pi package exposes an executable `omp` wrapper and skips on Linux. |
| `smoke-build-toolchain`             | Required Bun, Prek, Oxlint/Oxfmt, Tsgolint, Tsgo, Uv, and Ruff commands exist. |
| `unit-mksystem`                     | `lib/mkSystem.nix` shape plus current user, Home Manager, host module, and skill-target wiring. |
| `unit-overlay`                      | `pkgs/default.nix` is a valid overlay and exposes the expected `pkgs.martin.*` attributes, descriptions, and CLI main programs. Darwin-only package evaluation is skipped on Linux. |
| `unit-format`                       | `formatter.<system>` is configured as `nixpkgs-fmt`, evaluates, and all flake Nix files are formatted. |
| `integration-configurations-eval`   | The flake's Darwin/NixOS configs evaluate and keep expected user, host, pure-Nix dotfile, required/forbidden toolchain, WSL, and agent-skills settings. |

## CI

`.github/workflows/build.yml` runs `nix flake check` on `macos-14` and
`ubuntu-latest`, then builds each system configuration in parallel jobs. The
macOS check path also builds the package smoke checks exposed from
`tests/default.nix`.
