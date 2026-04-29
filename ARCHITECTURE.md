# Nix Architecture — Martin's cross-platform config

> **Active target:** `darwinConfigurations.Martins-Mac-mini` (Apple Silicon, nix-darwin).
> **Last reviewed:** 2026-04-29.

This repository is Martin's cross-platform Nix configuration. The Mac is the active target; Linux/Omakub and NixOS targets are deliberately staged behind it.

## Contents

- [Target priority](#target-priority)
- [Repository layout](#repository-layout)
- [Composition model](#composition-model)
- [Layer boundaries: system, home, dotfiles](#layer-boundaries-system-home-dotfiles)
- [Where things belong: hosts vs modules vs pkgs](#where-things-belong-hosts-vs-modules-vs-pkgs)
- [Darwin modules](#darwin-modules)
- [Home Manager modules](#home-manager-modules)
- [Agent Skills](#agent-skills)
- [Package ownership](#package-ownership)
- [Homebrew family policy](#homebrew-family-policy)
- [Secrets, formatting, CI](#secrets-formatting-ci)
- [Workflows](#workflows)
- [Linux / Omakub plan](#linux--omakub-plan)
- [WSL and X230 scaffolds](#wsl-and-x230-scaffolds)
- [Reference repositories](#reference-repositories)
- [Guardrails](#guardrails)
- [Maintaining this document](#maintaining-this-document)
- [Citable references](#citable-references)

## Target priority

1. **Active — `darwinConfigurations.Martins-Mac-mini`.** Apple Silicon (`aarch64-darwin`), nix-darwin. Primary place to make this repo excellent. Intel Macs are out of scope.
2. **Future — `homeConfigurations.martinfan-omakub`.** Planned Home Manager profile for Ubuntu/Omakub (<https://omakub.org/>). Documentation/design target only; no flake output yet.
3. **Inactive scaffolds — `nixosConfigurations.wsl`, `nixosConfigurations.x230`.** Kept for future NixOS/WSL experimentation. Not production until evaluated on real Nix systems.

## Repository layout

```text
.
├── flake.nix                 # thin flake entry point
├── lib/mkSystem.nix          # shared Darwin/NixOS system constructor
├── hosts/
│   ├── darwin/default.nix    # Martins-Mac-mini host layer (active)
│   ├── wsl/default.nix       # NixOS-WSL scaffold (inactive)
│   └── x230/default.nix      # ThinkPad scaffold (inactive)
├── modules/
│   ├── darwin/               # nix-darwin shared modules
│   ├── nixos/                # shared NixOS module — staged for future hosts
│   └── home/                 # Martin's Home Manager profile
├── pkgs/                     # custom derivations + overlay (exposed as pkgs.martin.*)
├── references/               # external sample repos, never imported by the flake
├── home.nix                  # off-flake Home Manager fallback (escape hatch)
└── skills.nix                # off-flake agent-skills fallback (escape hatch)
```

`flake.nix` stays thin: it wires inputs, overlays, system outputs, and the formatter. Host- and feature-specific behavior belongs in `hosts/` and `modules/`. `references/` is for humans, never for Nix.

### Off-flake fallbacks

`home.nix` and `skills.nix` exist so Home Manager and the agent-skills bundle can be applied on a machine that has Nix but isn't currently driving this flake (e.g. a fresh checkout where `darwin-rebuild` hasn't run yet, or a future Linux box without a flake output). They duplicate intent; the flake remains the source of truth. Treat them as a recovery path and re-derive from the flake when possible.

## Composition model

`lib/mkSystem.nix` is the central constructor. Each system supplies three facts:

- **`system`** — platform triple, e.g. `aarch64-darwin`. Darwin vs NixOS is inferred from the suffix.
- **`user`** — Martin's username for that host.
- **`hostModule`** — host-specific module path under `hosts/`.

The constructor:

1. Selects nix-darwin or NixOS based on the `system` suffix.
2. Applies the shared overlay from `pkgs/default.nix`.
3. Imports shared platform modules.
4. Wires Home Manager as a system module.
5. Passes `inputs` and `currentSystemUser` through `specialArgs`.

Shared modules consume `currentSystemUser` instead of hard-coding `martinfan`. The profile is still Martin-specific; this is not a generic multi-user framework.

### The overlay

`pkgs/default.nix` exposes Martin's custom derivations under a single namespace:

```nix
final: prev: {
  martin = {
    # gemini-preview, amp, pi, oh-my-pi, dropbox, drive, raycast, ...
  };
}
```

`pkgs.martin.*` is the canonical place for derivations Martin owns or vendors. Anything outside it should come from upstream `nixpkgs`.

## Layer boundaries: system, home, dotfiles

Three layers, one writer per concern:

| Layer               | Tool                           | Owns                                                                 |
|---------------------|--------------------------------|----------------------------------------------------------------------|
| System              | nix-darwin / NixOS             | OS settings, users, shells, services, system apps                    |
| User packages       | Home Manager                   | per-user CLI/dev packages, activation scripts                        |
| Selected config     | Home Manager `martin.*` modules | Nix-owned config files that have explicit options and cutover guards |
| Remaining dotfiles  | chezmoi / dotfiles             | config files not yet migrated into a Nix module                      |

Home Manager still installs many binaries (`sheldon`, `git`, `fd`, `rg`, …) without enabling the matching `programs.<tool>` modules when chezmoi owns those configs. The exception is explicit Nix ownership under options such as `martin.prompt.starship.*` and `martin.dotfiles.*`. Those modules must guard live paths before Home Manager links files into `$HOME`.

### Migrating a config file from chezmoi to Nix

Do this one config boundary at a time:

1. Stop tracking the file or directory in chezmoi.
2. Remove the live unmanaged path from `$HOME`.
3. Enable the relevant `martin.*` Home Manager option on the host.
4. Rebuild and verify the target is a symlink into `/nix/store`.

#### Worked example: `~/.config/starship.toml`

```bash
# 1-2. Hand off the file from chezmoi.
chezmoi forget --force ~/.config/starship.toml
rm ~/.config/starship.toml

# 3. Enable on the active host through Home Manager (in hosts/darwin/default.nix):
#    home-manager.users.${currentSystemUser}.martin.prompt.starship.enable = true;
#    home-manager.users.${currentSystemUser}.martin.prompt.starship.palette.enable = true;
#    home-manager.users.${currentSystemUser}.martin.prompt.starship.powerline.enable = true;
#    home-manager.users.${currentSystemUser}.martin.prompt.starship.segments.{rootIndicator,path,git,status,rPromptTime}.enable = true;

# 4. Activate.
sudo darwin-rebuild switch --flake .#Martins-Mac-mini

# Verify Nix ownership.
ls -la ~/.config/starship.toml      # → symlink into /nix/store/...
```

`modules/home/prompt.nix` and `modules/home/dotfiles/lib.nix` add activation-time guards that abort the rebuild with a specific remediation message if steps 1–2 are skipped, instead of Home Manager's generic "file in the way" error.

## Where things belong: hosts vs modules vs pkgs

| If the change is…                                                | Put it in…                                |
|------------------------------------------------------------------|-------------------------------------------|
| Specific to one machine (hostname, primary user, host-only apps) | `hosts/<host>/default.nix`                |
| Shared across all Darwin hosts                                   | `modules/darwin/<topic>.nix`              |
| Shared across all NixOS hosts                                    | `modules/nixos/<topic>.nix`               |
| User-level package or activation                                 | `modules/home/<topic>.nix`                |
| Custom-built or vendored package                                 | `pkgs/<name>.nix` exposed via the overlay |
| External sample code, reference only                             | `references/<repo>/` (read-only)          |

When a change fits two slots, prefer the more specific one and lift it later when a second consumer appears.

## Darwin modules

```text
modules/darwin/
├── default.nix            # imports the Darwin module set + base nixpkgs config
├── nix.nix                # flakes / nix-command / trusted users / GC policy
├── shell.nix              # zsh shell registration
├── security.nix           # Touch ID sudo
├── system-defaults.nix    # aggressive, opinionated macOS defaults
└── brew-variants.nix      # dormant brew-family scaffolds (see policy below)
```

The active Darwin host (`hosts/darwin/default.nix`) sets:

- the current user's macOS home directory,
- `system.primaryUser`,
- `system.stateVersion`,
- system-level GUI packages from `pkgs.martin`,
- and a default `martin.dotfiles` set for low-risk CLI UX assets.

`system.stateVersion` is set once per host and is **not** bumped casually — bumping it opts into nix-darwin's newer defaults, which is independent of upgrading nixpkgs.

## Home Manager modules

```text
modules/home/
├── default.nix         # username, homeDirectory, stateVersion, imports
├── packages.nix        # common + Darwin-only packages
├── dotfiles/           # option-gated adapted dotfiles from references/dotfiles-main
├── prompt.nix          # option-gated Starship config (dormant by default; replaces chezmoi-owned starship.toml when enabled)
└── skills.nix          # agent skill bundle activation
```

Common packages should be portable across Mac, future Omakub Home Manager, and NixOS where practical. Darwin-only packages live behind `pkgs.stdenv.isDarwin` checks.

### Dotfiles module set

`modules/home/dotfiles/` is the maintained Nix-owned copy of selected assets adapted from `references/dotfiles-main/`; modules must never import from `references/` directly. The public option namespace is `martin.dotfiles.*`.

Default active Darwin host settings enable only the low-risk static/dev-tool set:

```nix
home-manager.users.${currentSystemUser}.martin.dotfiles = {
  keymap.profile = "vim";
  bat.enable = true;
  less.enable = true;
  lazygit.enable = true;
  rules.enable = true;
};
```

High-blast-radius modules (`zsh`, `tmux`, `yazi`, `kitty`, `nvim`, `mpv`) are present but disabled by default. `nvim.enable` additionally requires `nvim.allowRuntimeManagers = true`, because the reference config self-bootstraps `lazy.nvim` and Mason outside pure Nix. `kitty.allowRemoteControl` and `tmux.enableTpm` are explicit opt-ins for socket remote-control and TPM behavior.

Keymap profiles are shared across keymap-heavy assets: `vim` is the default conventional h/j/k/l profile; `sxyazi` preserves the reference u/e/n/i movement model and CSI-u terminal integration. If a tool's upstream defaults are already vim-like, the `vim` profile should avoid unnecessary full-file remaps.

Every enabled dotfile path uses an activation guard from `modules/home/dotfiles/lib.nix`. If a live target exists and is not a symlink into `/nix/store`, activation aborts with a `chezmoi forget --force ...` and remove-path remediation message.

## Agent Skills

This section is the largest because the moving parts (sources, targets, discovery rules, editor support) are the most fragile.

### Mechanism

`modules/home/skills.nix` imports `inputs.agent-skills.homeManagerModules.default` and uses the upstream `programs.agent-skills` DSL — no custom activation scripts. The module owns one declarative bundle of selected `SKILL.md` directories and syncs that bundle to enabled targets via rsync.

### Enabled targets

| Target option       | Path                                              | Why                                                                                       |
|---------------------|---------------------------------------------------|-------------------------------------------------------------------------------------------|
| `targets.agents`    | `$HOME/.agents/skills`                            | Shared Open Agent Skills registry. Primary path for Codex and a documented Cursor path.   |
| `targets.claude`    | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills`      | Claude Code personal skills.                                                              |
| `targets.cursor`    | `$HOME/.cursor/skills`                            | Cursor-native user skills (deterministic discovery).                                      |
| `targets.codex`     | `${CODEX_HOME:-$HOME/.codex}/skills`              | Compatibility mirror only. The primary Codex path is `$HOME/.agents/skills`.              |
| `targets.pi`        | `$HOME/.pi/agent/skills`                          | Custom target — Oh My Pi / Pi harness.                                                    |

### Sources and selection

```nix
# `input` references a flake input declared in flake.nix.
programs.agent-skills = {
  enable = true;

  sources = {
    dotfiles-pi     = { input = "dotfiles";          subdir = "dot_pi/agent/skills"; };
    dotfiles-claude = { input = "dotfiles";          subdir = "dot_claude/skills"; };
    grill-me        = { input = "mattpocock-skills"; subdir = "grill-me"; };
  };

  skills.enable = [
    "git-workflow"
    "grill-me"
    "lazygit"
    "ralph-loop"
    "review"
    "web-browser"
  ];
};
```

### Policy

- **Publish once, mirror deliberately.** Build one Nix-managed bundle, then mirror only to agent-native directories whose discovery behavior is documented or consciously accepted.
- **Allowlist public sources.** Use `skills.enable = [ … ]` for third-party sources. Reserve `skills.enableAll = [ "source" ]` for tightly trusted private sources.
- **Disambiguate name collisions.** If two sources expose the same skill name, set `idPrefix` on one and enable the prefixed IDs (e.g. `openai/pdf`, `anthropic/pdf`).
- **Recursive discovery by default.** Keep `filter.maxDepth = null`. Use `filter.maxDepth = 1` only for known-flat roots (e.g. the curated dotfiles folders).
- **Bundle Nix-provided tools.** Use `skills.explicit.<name>.packages` and `transform` when a skill needs Nix-provided binaries; this avoids assuming globally installed tools.
- **Leave room for agent-managed subtrees.** Keep `excludePatterns = [ "/.system" ]` unless Nix must own every file in the target directory.
- **Adding a target is a deletion contract.** Each enabled target uses rsync with deletion semantics — Nix becomes authoritative for that directory. Enable new targets deliberately.

### Project-local skills

Project-local skills are a separate decision from user-global skills. Use upstream `mkLocalInstallScript` or `mkShellHook` with `defaultLocalTargets` when a repo should receive generated local skills under `.agents/skills`, `.claude/skills`, `.cursor/skills`, or `.codex/skills`.

- Use **`copy-tree`** for local targets so contributors can inspect or edit generated files without chasing Nix store symlinks.
- Use **`symlink-tree`** for global Home Manager targets.
- Avoid **`link`** when the destination uses shell variables (e.g. `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`); `home.file` cannot expand them at activation time.

### Editor support

Zed and VS Code are not equivalent skill targets today.

- **Zed** documents `.rules`, `.cursorrules`, `AGENTS.md`, `CLAUDE.md`, and related rule files. Agent Skills support is in an open upstream PR (zed-industries/zed#50453), not a documented stable release target.
- **VS Code Copilot** documents `AGENTS.md`, `.github/copilot-instructions.md`, and `.github/instructions/*.instructions.md`, not `SKILL.md` directories.

For these editors, keep shared instructions in `AGENTS.md` and add editor-native rule/instruction files only when needed. Do **not** invent Nix skill mirrors until the editor documents a stable skills path.

### Design Q&A (self-grilled)

| Question                                                                           | Answer                                                                                                       |
|------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------|
| Use raw library functions or the Home Manager DSL?                                 | DSL. Stays aligned with upstream options, target defaults, warnings, and future `agent-skills-nix` changes.  |
| Is `$HOME/.agents/skills` or `$HOME/.codex/skills` the Codex source of truth?      | `$HOME/.agents/skills`. Codex documents it; `targets.codex` is a compatibility mirror.                       |
| Should Zed and VS Code targets be created preemptively?                            | No. Both currently want rules/instructions, not declared `SKILL.md` mirrors.                                 |
| What is the main operational risk?                                                 | Enabled targets are rsync-managed. Adding one can delete unmanaged files in that directory.                  |

## Package ownership

Default policy: **pure Nix first.**

- **CLI / dev tools** → `modules/home/packages.nix`.
- **Mac GUI apps Martin owns or vendors** → custom derivations in `pkgs/`, exposed as `pkgs.martin.<name>`, declared on the Darwin host where appropriate.
- **System-level Mac apps currently in scope** — Dropbox, Google Drive, Raycast — declared on the Darwin host via `pkgs.martin.*`. Anything not yet packaged as a derivation is tracked as an explicit gap until it has one; brew is **not** a fallback.
- **Agent / dev tooling** — Gemini preview, Amp, Pi, Oh My Pi — packaged in `pkgs/` as custom derivations.

A tool should never be installed simultaneously through Nix and a brew variant unless it is a temporary migration step; record the migration intent in the same commit if so.

## Homebrew family policy

Brew-family tools are real Darwin options but stay dormant by default:

```nix
martin.brew.homebrew.enable = false;
martin.brew.zerobrew.enable = false;
martin.brew.zigbrew.enable  = false;
```

- Target Homebrew usage is effectively zero.
- Prefer Nix / custom derivations for declarative apps.
- Homebrew is reserved as an emergency / ad-hoc scaffold.
- `zerobrew` and `zigbrew` are documentation-only scaffolds for now.
- **Never** use Homebrew `cleanup = "zap"` unless every cask of value is declaratively owned.

If `martin.brew.homebrew.enable = true` is set explicitly, nix-darwin's Homebrew integration uses `onActivation.cleanup = "none"` to avoid destructive cleanup.

## Secrets, formatting, CI

These are dimensions every reviewer asks about. State the position even when the answer is "not yet."

| Concern              | Current state                                                                                  |
|----------------------|------------------------------------------------------------------------------------------------|
| Secrets management   | **None today.** No `sops-nix` / `agenix`. Secrets live outside the flake; revisit before adding any service that reads them. |
| Formatter            | Wired through `flake.nix` (`formatter.<system>`). Run via `nix fmt`.                           |
| Linting              | Manual `nix flake check`.                                                                      |
| CI                   | **None today.** Pre-merge verification is local `darwin-rebuild build`.                        |
| Dev shells / direnv  | Not currently exposed. If `devShells.<system>` is added later, document the `.envrc` pattern. |

When any row changes, update this table in the same PR.

## Workflows

### Build and switch the active Mac config

```bash
# Dry-run / build without activating
darwin-rebuild build --flake .#Martins-Mac-mini

# Activate
sudo darwin-rebuild switch --flake .#Martins-Mac-mini
```

### Roll back a bad activation

```bash
# List previous generations
darwin-rebuild --list-generations

# Roll back to the previous generation
sudo darwin-rebuild --rollback

# Or activate a specific generation
sudo darwin-rebuild --switch-generation <N>
```

### Roll back a single prompt setting

`martin.prompt.starship` is composed of independently-toggleable
`mkEnableOption`s — disable any one without affecting the rest:

```bash
# Edit hosts/darwin/default.nix, e.g.:
#   martin.prompt.starship.segments.rPromptTime.enable = false;

sudo darwin-rebuild switch --flake .#Martins-Mac-mini
```

The toggle ladder, finest → coarsest:

| Disable                                                        | Effect                                  |
|----------------------------------------------------------------|-----------------------------------------|
| `martin.prompt.starship.segments.<name>.enable = false`        | Drops one segment; others unchanged.    |
| `martin.prompt.starship.palette.enable = false`                | Falls back to bold styles, no colors.   |
| `martin.prompt.starship.powerline.enable = false`              | Drops chevrons; backgrounds remain.     |
| `martin.prompt.starship.enable = false`                        | Disables Starship; `~/.config/starship.toml` becomes unmanaged again (chezmoi can re-claim it). |

If a prompt regression makes the shell unusable mid-session, the larger blast
radius is generation rollback (above): `sudo darwin-rebuild --rollback`.

### Add a CLI tool

1. Add portable tools to the common package list in `modules/home/packages.nix`.
2. Add Darwin-only tools under the Darwin package list (gated by `pkgs.stdenv.isDarwin`).
3. `darwin-rebuild build` first, then `switch`.

### Add a Mac GUI app

1. Prefer a custom derivation in `pkgs/<name>.nix`.
2. Expose it from `pkgs/default.nix` under `pkgs.martin.<name>`.
3. Add it to `hosts/darwin/default.nix` if it is system-level (rather than per-user).

### Add or change an agent skill

1. Add the upstream source as a flake `input` (allowlist preferred for public sources).
2. Add a `programs.agent-skills.sources.<name>` entry.
3. Add specific IDs to `skills.enable` (or use `idPrefix` on collision).
4. Build, switch, and verify the bundle in `$HOME/.agents/skills` before checking other mirrors.

### Update inputs

```bash
# Update everything
nix flake update

# Update a single input (preferred for targeted bumps)
nix flake update <input-name>

# Verify before activating
darwin-rebuild build --flake .#Martins-Mac-mini
sudo darwin-rebuild switch --flake .#Martins-Mac-mini
```

## Linux / Omakub plan

Omakub is Ubuntu-focused, so Linux support is staged in two tracks:

1. **Short term:** continue testing against NixOS-based scaffolds (`wsl`, `x230`) for parity and migration sanity.
2. **Medium term:** introduce a dedicated `homeConfigurations.martinfan-omakub` output when the following are confirmed:
   - architecture and Nix user model,
   - username/home path contract,
   - package split between shared/common and Ubuntu-only,
   - final dotfiles ownership boundary.

Until then, Ubuntu/Omakub remains documented-only, with `home.nix` as a non-flake fallback for recovery.

## WSL and X230 scaffolds

`wsl` and `x230` are intentionally inactive NixOS scaffolds:

- `wsl` remains the platform for Windows-subsystem Linux experiments.
- `x230` remains the laptop/NixOS hardware path for future physical-machine tests.

Both share the same `modules/nixos/default.nix` baseline and `modules/home` user profile.

Build checks (or quick offline validation):

```bash
nix build .#nixosConfigurations.wsl.config.system.build.toplevel
nix build .#nixosConfigurations.x230.config.system.build.toplevel
```

When you switch a real machine:

```bash
# On a Linux machine evaluating this checkout with an active target:
sudo nixos-rebuild switch --flake .#wsl    # (equivalently .#nixosConfigurations.wsl)
sudo nixos-rebuild switch --flake .#x230   # (equivalently .#nixosConfigurations.x230)
```

Current WSL host defaults now include a conservative baseline (`hostName`, `defaultUser`, `startMenuLaunchers`, and `/mnt` automount root). Expand with care; keep `wsl`/`x230` as experimental scaffolds until real-world validation proves stable.

## Reference repositories

`references/` holds external sample codebases kept for learning. **Nothing in `references/` is a flake input or imported anywhere.**

| Repo                                  | Borrow for…                                                                                          |
|---------------------------------------|------------------------------------------------------------------------------------------------------|
| `references/nix-config-kyura/`        | Program/package splits, Darwin defaults, font/app examples, overlays.                                |
| `references/nixos-config-mitchellh/`  | Simple `mkSystem`, machine/user/home separation, pragmatic WSL/VM scaffolding.                       |
| `references/agent-skills-nix-master/` | Home Manager DSL, target syncing, local install scripts, skill packaging patterns.                   |
| `references/dotfiles-main/`       | Source material for adapted zsh/tmux/lazygit/bat/less/yazi/kitty/nvim/mpv/rules assets; never an active import path. |

Borrow patterns selectively. Do not copy Linux-specific NixOS concepts into nix-darwin modules without translation.

## Guardrails

- Mac is the active target; optimize for it first.
- Keep the flake root thin — inputs, overlays, system outputs, formatter, nothing else.
- Keep shared modules parameterized by `currentSystemUser`.
- Keep Home Manager from clobbering chezmoi-owned config files.
- Keep brew variants disabled unless explicitly testing an escape hatch.
- Treat sample repos as references, never as active configuration.
- Copy/adapt selected dotfile assets into `modules/home/dotfiles/assets/`; do not import them from `references/` directly.
- Keep `martin.dotfiles.keymap.profile = "vim"` as the default; make nonstandard movement opt-in.
- Adding an agent-skills target enables rsync-with-delete on that directory; enable deliberately.

## Maintaining this document

Update this doc in the same PR when you:

- change `lib/mkSystem.nix` semantics,
- add or remove a flake output,
- add or retire a host or module directory,
- change the Homebrew/zerobrew/zigbrew default,
- change the agent-skills target set or policy,
- add CI, formatter, or secrets management,
- promote Omakub or any inactive scaffold to active.
- change `martin.dotfiles.*` ownership, defaults, or keymap profile semantics.

Bump the **Last reviewed** date at the top whenever you re-read the whole doc end-to-end.

## Citable references

- Agent Skills specification — <https://agentskills.io/specification>
- `agent-skills-nix` target matrix and Home Manager DSL — <https://github.com/Kyure-A/agent-skills-nix#default-target-paths>
- Codex Agent Skills locations — <https://developers.openai.com/codex/skills#where-to-save-skills>
- Claude Code skills locations and frontmatter — <https://code.claude.com/docs/en/skills#where-skills-live>
- Cursor skill directories and compatibility paths — <https://cursor.com/docs/skills#skill-directories>
- Zed rules-file behavior — <https://zed.dev/docs/ai/rules#rules-files>
- Zed Agent Skills implementation status — <https://github.com/zed-industries/zed/pull/50453>
- VS Code Copilot custom instructions — <https://code.visualstudio.com/docs/copilot/customization/custom-instructions>
