# Defer a `martin.ai.enable` cluster toggle until a second real adapter exists

Status: deferred

An architecture review proposed one `martin.ai.enable` option (default `true`) to wrap 10 AI modules in `modules/home/`. Those modules are `claude.nix`, `ai-cli.nix`, `ai-model-routing.nix`, `droid.nix`, `amp.nix`, `opencode.nix`, `crush.nix`, `skill-router.nix`, `cursor.nix`, and `zed.nix`. A prototype spike (commit `a40f0e7`) proved that wrapping them in `lib.mkIf config.martin.ai.enable` leaves default output unchanged. We defer the toggle because every host currently imports the full `modules/home` profile and no host disables AI tools.

## Considered options

- **Land `martin.ai.enable` now across all 10 modules.** Rejected for now: the Linux scaffolds make zero `martin.*` overrides, and `martinfan-omakub` has not settled whether CLI and editor tools share one toggle.
- **Also gate `lsp.nix` and `packages.nix` under `martin.ai.enable`.** Rejected: Neovim uses `lsp.nix` independent of AI agents, and `packages.nix` splits packages only by common vs Darwin.
- **Defer the toggle until a second active host or Omakub profile needs it (chosen).** Avoids maintaining a speculative option across 10 files before a consumer defines the boundary.

## Consequences and trade-offs

- Inactive Linux scaffold evaluations in CI continue to evaluate the cross-platform AI modules (which also exercises `integration-home-linux-purity`).
- Disabling the AI toolset on a future host requires applying the mechanical `lib.mkIf` wrap when that host lands.
- **Reversal trigger:** Activate `homeConfigurations.martinfan-omakub` or a NixOS host that disables AI modules, or measure a CI eval bottleneck on Linux scaffolds.
