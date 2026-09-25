# Tests

Lightweight test suite for this flake. Wired into `flake.nix` as
`checks.<system>` so `nix flake check` runs everything.

## Layout

```
tests/
|-- default.nix                              # entry point, builds the check set
|-- lib/
|   |-- assertions.nix                       # tiny assertTest / testSuite helpers
|   `-- zsh-module-eval.nix                  # evaluates modules/home/zsh.nix standalone for cheap toggles
|-- unit/
|   |-- mksystem-test.nix                    # lib/mkSystem.nix shape and current host contract
|   |-- overlay-test.nix                     # pkgs/default.nix overlay, attrs, metadata
|   |-- format-test.nix                      # formatter wiring and nixpkgs-fmt check
|   |-- skill-router-test.nix                # runs the tools/skill-router bun suite offline (spawn-seam gate)
|   |-- claude-settings-ownership-test.nix   # generated settings reconciler fixture
|   |-- claude-settings-ownership-test.sh    # temporary-home behavior checks
|   |-- adr-files-test.sh                    # docs/adr holds only .md files
|   |-- adr-numbers-test.sh                  # ADR number prefixes are present and unique
|   |-- doc-links-test.sh                    # relative links in maintained docs resolve
|   |-- doc-checks-fixtures-test.sh          # the three docs checks fail on broken fixtures
|   |-- build-workflow-test.sh               # CI builds every checks.<system> name, none by hand
|   `-- zsh-vi-mode-test.sh                  # martin.shell.viMode keymap contract in a sandboxed zsh
`-- integration/
    `-- configurations-eval-test.nix         # current darwin/nixos configs and module outputs
```

## Running locally

```bash
# Every checks.aarch64-darwin attribute plus the darwin system build
just check

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
| `unit-mksystem`                     | `lib/mkSystem.nix` shape plus current user, host platform, Home Manager, host module, and skill-target wiring. |
| `unit-overlay`                      | `pkgs/default.nix` is a valid overlay and exposes the expected `pkgs.martin.*` attributes, descriptions, and CLI main programs. Darwin-only package evaluation is skipped on Linux. |
| `unit-format`                       | `formatter.<system>` is configured as `nixpkgs-fmt`, evaluates, and all flake Nix files are formatted. |
| `unit-agent-guides`                 | Checks every catalog host's rendered guides for required sections and tools, banned terms, model ids, and complete cross-guide pointers. |
| `unit-adr-files`                    | `docs/adr/` holds only `.md` files, so no rendered page or export sits beside an ADR as a second copy. |
| `unit-adr-numbers`                  | Every ADR name starts with a four-digit number, and no two ADRs share one. |
| `unit-doc-links`                    | Relative links and images in `docs/**/*.md`, `AGENTS.md`, `ARCHITECTURE.md`, and `CONTEXT.md` resolve to existing paths. Skips URLs, anchors, fenced blocks, and inline code. |
| `unit-doc-checks-fixtures`          | The three docs checks pass a clean fixture tree and fail broken ones, naming the offending file. |
| `unit-build-workflow`               | Both `build.yml` check jobs read the `checks.<system>` names with `builtins.attrNames` and build them all. The workflow names no check by hand. |
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

`.github/workflows/build.yml` does not run `nix flake check`. Two jobs build
the checks:

- `flake-check` on `ubuntu-latest` builds every `checks.x86_64-linux` attribute.
- `darwin` on `macos-14` builds every `checks.aarch64-darwin` attribute.

Each job reads the names with `builtins.attrNames`, as `just check` does. A
check added to `tests/default.nix` therefore runs in CI with no workflow edit.
`unit-build-workflow` fails if `build.yml` names an individual check.
Platform-specific checks skip themselves off-platform, so both jobs build the
same names.

After its checks, the `darwin` job builds the dev shell and runs the
source-build guard. Then it builds `darwinConfigurations.f`. The `nixos` and
`nixos-aarch64` jobs build the NixOS hosts. They and `darwin` start once
`flake-check` passes.

`unit-skill-router` runs in both jobs, so the `tools/skill-router` bun suite
runs on both runners. It uses the canary Bun on macOS and stock `pkgs.bun` on
Linux. It is the only automated gate on the spawn seam. Run it locally with
`just test-router`.
