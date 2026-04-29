# AGENTS.md

## Scope

This repository is Martin's cross-platform Nix configuration. The active target is `darwinConfigurations.Martins-Mac-mini` on `aarch64-darwin`; `nixosConfigurations.wsl`, `nixosConfigurations.x230`, and `nixosConfigurations.vm-aarch64-utm` are scaffolds that still evaluate in CI but are not treated as production hosts.

## What Matters Most

- Keep `flake.nix` thin. It should only wire inputs, overlays, system outputs, formatter, and checks. Push behavior down into `lib/`, `hosts/`, `modules/`, or `pkgs/`.
- `lib/mkSystem.nix` is the central constructor. It decides Darwin vs NixOS from the `system` suffix, applies the shared overlay, wires Home Manager, and passes `inputs` plus `currentSystemUser` via `specialArgs`. If you change its semantics, update tests and architecture docs together.
- Prefer the most specific layer first: host-specific changes in `hosts/<host>/default.nix`, shared platform behavior in `modules/darwin` or `modules/nixos`, user-level packages and activation in `modules/home`, custom packages in `pkgs/`.
- `references/` is for humans only. Nothing there is imported by the flake. Do not wire code from `references/` into live configuration.

## Repository Shape

- `flake.nix`: entry point, inputs, outputs, formatter, `checks`
- `lib/mkSystem.nix`: shared system factory for Darwin and NixOS
- `hosts/`: host-specific system modules
- `modules/darwin`: shared nix-darwin modules, including dormant Homebrew scaffolds
- `modules/nixos`: shared NixOS baseline for `wsl`, `x230`, and `vm-aarch64-utm`
- `modules/home`: Home Manager profile, prompt, skills, editor/agent shims
- `pkgs/`: overlay and custom derivations exposed under `pkgs.martin.*`; `crush` is also overridden here
- `tests/`: flake checks, unit tests, integration evaluation tests, smoke checks
- `scripts/update-*.sh`: per-package auto-bump scripts used by CI
- `home.nix`, `skills.nix`: off-flake escape hatches, not the main source of truth
- `ARCHITECTURE.md`: detailed design and policy document
- `PANIC.md`: rollback procedure for auto-update regressions

## Essential Commands

### Build and activate

```bash
darwin-rebuild build --flake .#Martins-Mac-mini
sudo darwin-rebuild switch --flake .#Martins-Mac-mini
```

### Rollback

```bash
darwin-rebuild --list-generations
sudo darwin-rebuild --rollback
sudo darwin-rebuild --switch-generation <N>
```

### Format and checks

```bash
nix fmt
nix flake check --print-build-logs
nix flake check --show-trace --print-build-logs
```

### Targeted checks

```bash
nix build .#checks.aarch64-darwin.unit-mksystem --no-link
nix build .#checks.aarch64-darwin.unit-overlay --no-link
nix build .#checks.aarch64-darwin.unit-format --no-link
nix build .#checks.aarch64-darwin.integration-configurations-eval --no-link
nix build .#checks.aarch64-darwin.integration-darwin-package-wrappers --no-link
nix build .#checks.aarch64-linux.integration-configurations-eval --no-link
nix eval --json '.#checks.aarch64-darwin' --apply 'builtins.attrNames'
```

Replace `aarch64-darwin` with `x86_64-linux` on ordinary Linux, or `aarch64-linux` for the UTM VM scaffold.

### Input updates

```bash
nix flake update
nix flake update <input-name>
```

Always build before switching after input changes.

## Architecture and Control Flow

`flake.nix` constructs systems by calling `lib/mkSystem.nix` with `{ system, user, hostModule }`. `mkSystem` selects `darwinSystem` or `nixosSystem`, applies the shared overlay from `pkgs/default.nix`, imports the platform module set, wires Home Manager as a system module, and injects `currentSystemUser`.

The overlay in `pkgs/default.nix` is the canonical namespace for custom packages: `pkgs.martin.dropbox`, `google-drive`, `raycast`, `gemini-cli-preview`, `sourcegraph-amp`, `droid`, `opencode`, `opencode-electron`, `pi-coding-agent`, and `oh-my-pi`. If a package is Martin-owned or vendored, it belongs under `pkgs.martin.*` instead of scattered host logic.

The active Darwin host only sets a small amount of host-specific state: macOS home path, `system.primaryUser`, `system.stateVersion`, and system-level GUI apps. Shared Darwin behavior stays in `modules/darwin`. Shared NixOS defaults stay in `modules/nixos`. User-facing tools and activation hooks stay in `modules/home`.

## Non-Obvious Conventions

### Home Manager vs chezmoi ownership

Home Manager intentionally installs binaries like `starship`, `git`, `bat`, `fd`, `rg`, `eza`, and `zoxide` without enabling matching `programs.<tool>` modules. Config text is expected to remain chezmoi-owned unless a module explicitly takes ownership. Do not “clean this up” by enabling Home Manager program modules broadly; that would clobber dotfiles managed elsewhere.

`modules/home/prompt.nix` is the clearest example: if `martin.prompt.starship.enable` is turned on, the activation script aborts when `~/.config/starship.toml` still exists as a regular file. The migration path is explicit:

```bash
chezmoi forget --force ~/.config/starship.toml
rm ~/.config/starship.toml
```

Then rebuild.

### Stable user-PATH symlink pattern

`modules/home/claude-code.nix`, `droid.nix`, and `opencode.nix` expose stable shims in `~/.local/bin/` instead of relying on store paths directly. This is done to avoid macOS TCC/editor integration churn across rebuilds. Follow this pattern when packaging other interactive agent tools.

### Mutable config seeding pattern

`modules/home/opencode.nix` writes `~/.config/opencode/opencode.json` only if absent, so Nix seeds defaults but the app can still mutate auth/runtime state later. If a tool needs a writable config after first run, prefer this seeded-but-mutable approach over forcing a read-only symlink.

### Agent skills are declarative and destructive by target

`modules/home/skills.nix` uses the upstream `agent-skills-nix` Home Manager module, not custom activation logic. Enabled skills are allowlisted with `skills.enable`; public sources are not enabled wholesale.

Targets include `.agents`, `.claude`, `.cursor`, `.codex`, and `.pi`. These sync with rsync-style deletion semantics, so enabling a target means Nix becomes authoritative for that directory. Treat new targets as a deletion contract.

`$HOME/.agents/skills` is the primary shared skills registry. The `.codex` target is only a compatibility mirror.

### Homebrew is an emergency scaffold, not a normal package path

`modules/darwin/default.nix` keeps `martin.brew.homebrew.enable = false`. `zerobrew` and `zigbrew` are documented-but-disabled options with assertions that prevent enabling them. If Homebrew is temporarily enabled, cleanup is forced to `none` specifically to avoid destructive behavior. Do not introduce brew as a casual fallback when a package could live in `pkgs/`.

### Sourcegraph Amp naming trap

`pkgs/sourcegraph-amp.nix` intentionally does not use upstream `nixpkgs#amp`, because that is a different project (`amp.rs`). The local package wraps the npm-distributed Sourcegraph agent tool instead. Preserve that distinction when upgrading or refactoring.

## Testing Strategy

`flake.nix` exposes tests through `checks.<system>`, so `nix flake check` is the top-level validation path. The test suite is intentionally light but covers key architecture contracts:

- `unit-mksystem`: verifies `mkSystem` shape and user/home-manager wiring
- `unit-overlay`: verifies overlay structure and expected `pkgs.martin.*` exports
- `unit-format`: verifies `nixpkgs-fmt` wiring and Nix formatting
- `integration-configurations-eval`: verifies Darwin and NixOS configurations still evaluate and preserve required settings
- `integration-darwin-package-wrappers`: builds Darwin custom packages and checks wrapper behavior
- `smoke-build-toolchain`: verifies required Bun/Prek/Oxlint/Oxfmt/Tsgolint/Tsgo/Uv/Ruff executables exist

When changing `lib/mkSystem.nix`, overlay exports, skill targets, or host/module boundaries, expect tests to encode those contracts already. Update the relevant assertions instead of working around failures.

## CI and Release Automation

`.github/workflows/build.yml` runs `nix flake check` on Linux and Darwin, builds the active Darwin host plus the x86_64 NixOS scaffolds, and builds `vm-aarch64-utm` on the `ubuntu-24.04-arm` runner. If you change outputs or host names, update CI in the same change.

`.github/workflows/auto-update.yml` runs all `scripts/update-*.sh` daily, opens a single combined PR, and auto-merges when CI is green. Failures in one updater are tolerated so the rest can still land. `PANIC.md` is the rollback playbook when an auto-update builds successfully but breaks at runtime.

## Update Script Patterns

The `scripts/update-*.sh` files are not generic; they encode package-specific bump logic. Common patterns:

- poll an upstream registry or GitHub release
- rewrite version and temporary fake hashes in `pkgs/*.nix`
- run `nix build` to capture the real hash from the failure output
- patch the discovered hash back in
- perform a final `nix build .#martin.<pkg> --no-link` validation

Examples worth copying from existing scripts:

- `scripts/update-droid.sh`: multi-platform hash discovery from npm tarballs
- `scripts/update-opencode.sh`: lockstep version bump across CLI and Electron packages

If you add a new auto-updated package, follow the existing fake-hash dance and add the updater to the `scripts/update-*.sh` set rather than inventing a separate workflow.

## Style and Naming Observations

- Keep modules small and purpose-specific. The repo favors narrowly scoped files like `shell.nix`, `security.nix`, `prompt.nix`, `skills.nix`, `zed.nix`.
- Prefer `currentSystemUser` over hard-coding `martinfan` inside shared modules. Host declarations still choose the concrete username.
- Darwin-only Home Manager packages are gated with `pkgs.stdenv.isDarwin`. Preserve that split instead of sprinkling platform checks across unrelated files.
- `system.stateVersion` values are treated as sticky host commitments, not version numbers to bump casually.
- When a change is only for one machine, keep it in that host file until a second consumer appears.

## Gotchas

- Do not import anything from `references/`. Those trees are learning material only.
- Do not assume WSL, `x230`, or `vm-aarch64-utm` are safe to optimize for beyond evaluation and test expectations. The Mac config is the priority.
- Do not replace the upstream `programs.agent-skills` DSL with hand-rolled activation scripts. The current design is intentionally upstream-aligned.
- Do not add Home Manager `programs.*` ownership for tools whose configs are still managed outside Nix.
- Do not switch Homebrew cleanup to `zap`.
- Do not remove stable `~/.local/bin/*` shims for interactive tools unless you also solve the TCC/editor path-stability problem they were introduced for.

## When To Update Docs

Update `AGENTS.md`, `ARCHITECTURE.md`, or `PANIC.md` together with code when you change any of the following:

- `lib/mkSystem.nix` behavior
- flake outputs or host inventory
- agent-skill sources, allowlists, or targets
- package ownership boundaries between `hosts/`, `modules/`, and `pkgs/`
- Homebrew policy
- CI or auto-update behavior
- prompt ownership/migration behavior
