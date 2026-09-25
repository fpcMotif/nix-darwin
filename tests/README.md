# Tests

Lightweight test suite for this flake. Wired into `flake.nix` as
`checks.<system>` so `nix flake check` runs everything.

## Layout

```
tests/
|-- default.nix                              # entry point, builds the check set
|-- lib/
|   |-- assertions.nix                       # tiny assertTest / testSuite helpers
|   |-- shell-home.nix                       # real Home Manager eval of only the shell modules
|   `-- zsh-module-eval.nix                  # evaluates modules/home/zsh.nix standalone for cheap toggles
|-- unit/
|   |-- mksystem-test.nix                    # lib/mkSystem.nix shape and current host contract
|   |-- overlay-test.nix                     # pkgs/default.nix overlay, attrs, metadata
|   |-- format-test.nix                      # formatter wiring and nixpkgs-fmt check
|   |-- skill-router-test.nix                # runs the tools/skill-router bun suite offline (spawn-seam gate)
|   |-- claude-settings-ownership-test.nix   # generated settings reconciler fixture
|   |-- claude-settings-ownership-test.sh    # temporary-home behavior checks
|   |-- fish-shell-test.sh                   # generated fish config in a sandboxed fish, all four modes
|   `-- zsh-vi-mode-test.sh                  # martin.shell.viMode keymap contract in a sandboxed zsh
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
nix build .#checks.aarch64-darwin.unit-auto-update --no-link
nix build .#checks.aarch64-darwin.unit-agent-guides --no-link
nix build .#checks.aarch64-darwin.unit-skill-router --no-link
nix build .#checks.aarch64-darwin.unit-skill-hygiene --no-link
nix build .#checks.aarch64-darwin.unit-claude-settings-ownership --no-link
nix build .#checks.aarch64-darwin.integration-configurations-eval --no-link
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
| `smoke-build-oh-my-pi`              | Darwin-only Oh My Pi package exposes an executable `omp` wrapper and skips on Linux. |
| `smoke-build-toolchain`             | Required Prek, Oxlint/Oxfmt, Tsgolint, Tsgo, Uv, and Ruff commands exist, plus the shipped canary Bun (and its `bunx` symlink) on Darwin. |
| `unit-auto-update`                  | Colored update summaries and the ownership-safe archived auto-switch source. |
| `unit-zsh-vi-mode`                  | Loads the rendered zshrc (home-manager section order emulated) in a sandboxed zsh and asserts the post-load keymap tables: fzf ^R/^T/alt-c widgets in BOTH viins and vicmd, prefix-history Up/Down, fn-Delete/Home/End/PageUp/PageDown/Shift-Tab, the keepEmacsKeys set in viins, v -> edit-command-line in vicmd, plugin widgets present, autosuggestions still wired. The regression gate for "enabling vi mode ate fzf ^R" (#328). |
| `unit-fish-shell`                   | Builds the shell modules' real Home Manager files with `martin.shell.interactive = "fish"` and runs a sandboxed fish in `-c`, `-lc`, `-ic`, and `-lic`: silent startup, exit status, no zsh launched or sourced, duplicate-free PATH with session tiers in order (clean and forked), exported variables and inherited terminfo, vi and search-plane bindings after the first-prompt load, abbreviations, interactive-only wrappers with argv and child-only env isolation (recording stubs, no real AI CLI reachable), direnv load and unload, zoxide, and a prompt that runs no external command (#385). |
| `unit-shell-switch`                 | `martin.shell.interactive` generates exactly one shell's config: fish without `.zshrc`, zsh without `config.fish`. |
| `unit-mksystem`                     | `lib/mkSystem.nix` shape plus current user, host platform, Home Manager, host module, and skill-target wiring. |
| `unit-overlay`                      | `pkgs/default.nix` is a valid overlay and exposes the expected `pkgs.martin.*` attributes, descriptions, and CLI main programs. Darwin-only package evaluation is skipped on Linux. |
| `unit-format`                       | `formatter.<system>` is configured as `nixpkgs-fmt`, evaluates, and all flake Nix files are formatted. |
| `unit-agent-guides`                 | Checks every catalog host's rendered guides for required sections and tools, banned terms, model ids, and complete cross-guide pointers. |
| `unit-claude-settings-ownership`          | Runs the production jq reconciler in temporary homes; checks own/default/add semantics, safe stale-key cleanup, dry-run immutability, and byte-identical no-ops. |
| `unit-ai-model-routing`             | One semantic job policy renders OMP, Pi, Codex, Crush, and Zed adapters. Search and check use Spark; general and plan use Terra; fallback uses Luna. GPT-5.5 and Sol are rejected. |
| `unit-skill-router`                 | Runs the `tools/skill-router` bun suite (`test/subprocess-gating.test.ts`) offline inside the Nix sandbox. Pins the spawn seam so `discover`/`load` never reach a real `bunx @tanstack/intent` subprocess unless package scope is explicitly requested (ADR-0006); the bundled `bunfig.toml` preload (`SKILL_ROUTER_NO_REAL_SPAWN`) makes any real spawn fail loud and offline. Uses the shipped canary Bun on Darwin, stock `pkgs.bun` on Linux. |
| `unit-skill-hygiene`                | Cross-source drift checks for the agent-skill curation lists: every exclusion term still names a live skill in the pinned `mattpocock-skills` buckets, no vendored fork under `modules/home/skills/` shadows a promoted upstream id, `cleanup.nix` still mirrors `skillTargetDirs`, and neither the retired Karpathy `transform`s nor the `mp-in-progress` source has crept back. Pure `readDir` — no IFD, so it evaluates the Linux hosts from Darwin. |
| `integration-configurations-eval`   | The flake's Darwin/NixOS configs evaluate and keep expected user, host, pure-Nix dotfile, activation dry-run, required/forbidden toolchain, and agent-skills settings, including one Claude settings reconciliation activation. |
| `integration-darwin-settings`       | Darwin-only. Exact-value assertions for every `system.defaults` key plus sudo Touch ID, firewall, pmset power management, the skhd-stays-disabled guard (BetterMouse tap conflict), and the Gatekeeper guard; font-bundle membership + count; Rime/Squirrel agent wiring, plus the guards that BetterMouse and BetterDisplay stay GUI-managed. No-op skip on Linux. |

Real-machine verification (Tier 2) lives outside the Nix checks in
`scripts/verify-macos-settings.sh` (run via `just verify-macos`) and
`scripts/verify-agent-skills.sh` (run via `just verify-skills`, which reads the
`~/.config/agent-skills/manifest.json` that `modules/home/claude.nix` emits on
every switch, so it never restates the curation lists); the deferred
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
