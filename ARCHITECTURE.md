# Nix Architecture — Martin's cross-platform config

> **Active target:** `darwinConfigurations.f` (Apple Silicon, nix-darwin).
> **Last reviewed:** 2026-05-24.

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
- [WSL, X230, and VM scaffolds](#wsl-x230-and-vm-scaffolds)
- [Reference repositories](#reference-repositories)
- [Guardrails](#guardrails)
- [Maintaining this document](#maintaining-this-document)
- [Citable references](#citable-references)

## Target priority

1. **Active — `darwinConfigurations.f`.** Apple Silicon (`aarch64-darwin`), nix-darwin. Primary place to make this repo excellent. Intel Macs are out of scope.
2. **Future — `homeConfigurations.martinfan-omakub`.** Planned Home Manager profile for Ubuntu/Omakub (<https://omakub.org/>). Documentation/design target only; no flake output yet.
3. **Inactive scaffolds — `nixosConfigurations.wsl`, `nixosConfigurations.x230`, `nixosConfigurations.vm-aarch64-utm`.** Kept for future NixOS/WSL/VM experimentation. Not production until evaluated on real Nix systems.

## Repository layout

```text
.
├── flake.nix                 # thin flake entry point
├── lib/mkSystem.nix          # shared Darwin/NixOS system constructor
├── hosts/
│   ├── darwin/default.nix    # f host layer (active)
│   ├── wsl/default.nix       # NixOS-WSL scaffold (inactive)
│   ├── x230/default.nix      # ThinkPad scaffold (inactive)
│   └── vm-aarch64-utm/       # UTM/QEMU aarch64 VM scaffold (inactive)
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
5. Passes `inputs`, `currentSystemUser`, and `currentSystemUserHome` through `specialArgs`.

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

| Layer          | Tool                | Owns                                                          |
|----------------|---------------------|---------------------------------------------------------------|
| System         | nix-darwin / NixOS  | OS settings, users, shells, services, system apps             |
| User packages  | Home Manager        | per-user CLI/dev packages, activation scripts                 |
| Config text    | Home Manager        | zsh, git, starship, tmux, Ghostty, shell/terminal preferences |

Home Manager now owns the selected shell, prompt, terminal, and git config text in Nix, including generated files like `~/.zshrc`, `~/.config/starship.toml`, `~/.config/tmux/tmux.conf`, `~/.config/ghostty/config`, and `~/.config/git/config`. Legacy Stow/Homebrew dotfiles are inventory only; they are not an active writer for migrated concerns.

### Migrating a config file into Nix ownership

Do this one file at a time:

1. Decide that the file should become Nix-owned configuration.
2. Move or remove the live unmanaged file from `$HOME`.
3. Enable the relevant Home Manager `programs.*` or `xdg.configFile` module.
4. Rebuild and verify ownership.

#### Worked example: `~/.config/starship.toml`

```bash
# 1-2. Hand off the file from manual management.
rm ~/.config/starship.toml

# 3. Enable on the active host (in hosts/darwin/default.nix):
#    martin.prompt.starship.enable = true;
#    martin.prompt.starship.palette.enable = true;
#    martin.prompt.starship.powerline.enable = true;
#    martin.prompt.starship.segments.{path,git,jj,status,rPromptTime}.enable = true;

# 4. Activate.
sudo darwin-rebuild switch --flake .#f

# Verify Nix ownership.
ls -la ~/.config/starship.toml      # → symlink into /nix/store/...
```

`modules/home/prompt.nix` generates a transparent-terminal-friendly Starship
theme: compact colored chips that start with the directory, a slim right prompt
for runtime/time context, and no terminal-wide background. The Git branch chip
is a small Starship custom module hidden inside Jujutsu repos, Git status stays
on Starship's fast native module, and Jujutsu uses a tiny `custom.jj` segment
that calls `jj` directly.

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
├── default.nix          # imports the Darwin module set + base nixpkgs config
├── brew-variants.nix    # dormant brew-family scaffolds (see policy below)
├── defaults.nix         # selected macOS keyboard, Finder, Dock, trackpad, screenshot defaults
├── fonts.nix            # system font installation
├── hammerspoon.nix      # Hammerspoon app/config integration
├── mouse-display.nix    # BetterMouse and display-adjacent Mac preferences
├── nix.nix              # flakes / nix-command / trusted users
├── rime.nix             # Rime input-method state and data paths
├── security.nix         # Touch ID sudo
├── shell.nix            # zsh shell registration
└── skhd.nix             # skhd hotkey daemon integration
```

The active Darwin host (`hosts/darwin/default.nix`) sets:

- the current user's macOS home directory (from `currentSystemUserHome`),
- `system.primaryUser`,
- `system.stateVersion`,
- system-level GUI packages from `pkgs.martin`.

The platform-specific home path is computed once in `lib/mkSystem.nix` and exposed as `currentSystemUserHome`, so the system layer (`users.users.<user>.home`) and the Home Manager profile (`home.homeDirectory`) both read the same value.

`system.stateVersion` is set once per host and is **not** bumped casually — bumping it opts into nix-darwin's newer defaults, which is independent of upgrading nixpkgs.

## Home Manager modules

```text
modules/home/
├── default.nix            # username, homeDirectory, stateVersion, imports
├── ai-cli.nix             # shared AI CLI package/config glue
├── ai-model-routing.nix   # model-router scripts and generated routing config
├── amp.nix                # Amp CLI wrapper/state integration
├── claude.nix             # Claude Code, agent-skills bundle, hooks, and managed Claude files
├── cleanup.nix            # user-level cleanup jobs and activation maintenance
├── crush.nix              # Crush CLI wrapper/config integration
├── cursor.nix             # Cursor settings, extensions, and activation glue
├── droid.nix              # Factory Droid package/config integration
├── ghostty.nix            # Ghostty config managed as XDG text
├── git.nix                # Git behavior without copied identity/signing keys
├── jujutsu.nix            # Jujutsu config and Git coexistence defaults
├── kitty.nix              # Kitty terminal config
├── lsp.nix                # shared LSP/editor config artifacts
├── obsidian.nix           # Obsidian app/config integration
├── opencode.nix           # OpenCode CLI/Electron wrappers and config seed
├── packages.nix           # common + Darwin-only packages
├── prompt.nix             # option-gated Starship config (enabled on active Mac)
├── ssh.nix                # SSH client config that avoids secrets in the flake
├── tmux.nix               # tmux behavior from legacy dotfiles, without TPM bootstrap
├── yazi.nix               # Yazi terminal file-manager config
├── zed.nix                # Zed settings and agent rules files
└── zsh.nix                # zsh, fzf, direnv, aliases/functions, editor env
```

Common packages should be portable across Mac, future Omakub Home Manager, and NixOS where practical. Darwin-only packages live behind `pkgs.stdenv.isDarwin` checks.

## Agent Skills

This section is the largest because the moving parts (sources, targets, discovery rules, editor support) are the most fragile.

### Mechanism

`modules/home/claude.nix` imports `inputs.agent-skills.homeManagerModules.default` and uses the upstream `programs.agent-skills` DSL for the skill bundle and target sync. The same module also owns Claude-specific activation scripts for mutable runtime state — settings seeding, Stop-hook diagnostics, and duplicate-skill cleanup — all running after Home Manager's `writeBoundary` and covered by integration assertions. The module owns one declarative bundle of selected `SKILL.md` directories and exposes that bundle to enabled targets via the upstream sync machinery.

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
    mp-engineering  = { input = "mattpocock-skills"; subdir = "skills/engineering"; };
    mp-productivity = { input = "mattpocock-skills"; subdir = "skills/productivity"; };
    mp-misc         = { input = "mattpocock-skills"; subdir = "skills/misc"; };
    effect-ts       = { input = "effect-ts-skills";  subdir = "skills"; };
  };

  skills = {
    enable = enabledMattpocockSkills; # all promoted Matt Pocock skills except disabledMattpocockSkills.
    enableAll = [ "effect-ts" ];
    explicit = {
      git-workflow = {
        from = "dotfiles-pi";
        path = "git-workflow";
        packages = [ pkgs.git pkgs.gh pkgs.jq ];
      };
      review = {
        from = "dotfiles-pi";
        path = "review";
        packages = [ pkgs.git pkgs.gh pkgs.jq ];
      };
      lazygit = {
        from = "dotfiles-claude";
        path = "lazygit";
        packages = [ pkgs.git pkgs.lazygit ];
      };
      ralph-loop = { from = "dotfiles-pi"; path = "ralph-loop"; packages = [ ]; };
      web-browser = { from = "dotfiles-pi"; path = "web-browser"; packages = [ ]; };
    };
  };
};
```

### Policy

- **Publish once, mirror deliberately.** Build one Nix-managed bundle, then mirror only to agent-native directories whose discovery behavior is documented or consciously accepted.
- **Allowlist public sources.** Use explicit skill entries for selected third-party skills when they need Nix-provided packages; otherwise `skills.enable = [ … ]` is acceptable. Reserve `skills.enableAll = [ "source" ]` for tightly trusted private sources.
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

### Pinning policy for vendored Mac apps

Fixed-output derivations under `pkgs.martin.*` must point at **immutable bytes**, not a "latest" alias, so CI does not break every time upstream rotates a release. Each derivation pins both `version = "X.Y.Z"` and a versioned URL — bumps become explicit reviewable changes, and a future hash mismatch signals real upstream tampering rather than a routine release.

Known irreducibility: Google does not publish versioned `.dmg` URLs for Drive for Desktop. `pkgs/google-drive.nix` keeps the `dl.google.com/drive-file-stream/GoogleDrive.dmg` URL, sets `version` to the current release for visibility, and accepts manual hash bumps as the cost of doing business. Adding a new vendored app under `pkgs.martin.*`: prefer a versioned URL; fall back to the Google Drive pattern only if upstream genuinely doesn't expose one, and record why in a comment on the derivation.

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
| Linting              | `nix flake check` runs `nixpkgs-fmt --check`, `statix`, and `deadnix --fail` via `tests/default.nix`. `statix.toml` disables only `repeated_keys` so Home Manager dotted assignments can stay local. Run locally and in CI. |
| CI                   | GitHub Actions (`.github/workflows/build.yml`): builds active Darwin, x86_64 NixOS scaffolds (`wsl`, `x230`), and `vm-aarch64-utm` on macOS / Ubuntu runners, with `nix flake check` as the gate before config builds. |
| Dev shells / direnv  | Not currently exposed. If `devShells.<system>` is added later, document the `.envrc` pattern. |

When any row changes, update this table in the same PR.

## Workflows

### Build and switch the active Mac config

```bash
# Dry-run / build without activating
darwin-rebuild build --flake .#f

# Activate
sudo darwin-rebuild switch --flake .#f
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

sudo darwin-rebuild switch --flake .#f
```

The toggle ladder, finest → coarsest:

| Disable                                                        | Effect                                  |
|----------------------------------------------------------------|-----------------------------------------|
| `martin.prompt.starship.segments.<name>.enable = false`        | Drops one segment; others unchanged.    |
| `martin.prompt.starship.palette.enable = false`                | Falls back to bold styles, no colors.   |
| `martin.prompt.starship.powerline.enable = false`              | Drops rounded chips and prompt guides.  |
| `martin.prompt.starship.enable = false`                        | Disables Starship; `~/.config/starship.toml` becomes unmanaged again. |

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
3. Add specific IDs to `skills.enable`, or prefer `skills.explicit.<name>` when you need to attach packages/metadata/renames.
4. Build, switch, and verify the bundle in `$HOME/.agents/skills` before checking other mirrors.

### Update inputs

```bash
# Update everything
nix flake update

# Update a single input (preferred for targeted bumps)
nix flake update <input-name>

# Verify before activating
darwin-rebuild build --flake .#f
sudo darwin-rebuild switch --flake .#f
```

## Linux / Omakub plan

Omakub is Ubuntu-focused, so it should not become a `nixosConfigurations.*` output. The likely future shape is a standalone Home Manager output:

```nix
homeConfigurations.martinfan-omakub
```

Do not add that output until these are settled:

- exact Linux architecture,
- username and home path,
- whether Nix is single-user or multi-user,
- which packages are shared with the Mac,
- which config files remain intentionally unmanaged.

Until then, Omakub is a design target documented here only.

## WSL, X230, and VM scaffolds

`wsl`, `x230`, and `vm-aarch64-utm` remain in the flake as inactive NixOS scaffolds. They are useful for future experimentation — Windows-app testing, NixOS-on-laptop experiments, and a UTM/QEMU guest path — but they are lower priority than Mac and future Omakub.

The VM scaffold is intentionally adapted from `references/nixos-config-mitchellh/`, which is the primary reference for VM-machine shape in this repo. Local comparison trees may be reviewed for ideas, but VM-machine defaults should prefer the senior/reference implementation unless a local requirement overrides it. The current VM assumes an Apple Silicon host with an ARM64 UTM/QEMU guest, UEFI boot, and labelled `nixos`/`boot` filesystems.

Build checks:

```bash
nix build .#nixosConfigurations.wsl.config.system.build.toplevel
nix build .#nixosConfigurations.x230.config.system.build.toplevel
nix build .#nixosConfigurations.vm-aarch64-utm.config.system.build.toplevel
```

The `vm-aarch64-utm` build requires an aarch64-linux-capable builder or substituter; GitHub Actions uses an ARM Ubuntu runner for CI, but do not assume a macOS workstation can locally build the full Linux closure.

Do not assume they are production-ready until they have been evaluated on real Nix systems.

## Reference repositories

`references/` holds external sample codebases kept for learning. **Nothing in `references/` is a flake input or imported anywhere.**

| Repo                                  | Borrow for…                                                                                          |
|---------------------------------------|------------------------------------------------------------------------------------------------------|
| `references/nix-config-kyura/`        | Program/package splits, Darwin defaults, font/app examples, overlays.                                |
| `references/nixos-config-mitchellh/`  | Simple `mkSystem`, machine/user/home separation, pragmatic WSL/VM scaffolding.                       |
| `references/agent-skills-nix-master/` | Home Manager DSL, target syncing, local install scripts, skill packaging patterns.                   |

Borrow patterns selectively. Do not copy Linux-specific NixOS concepts into nix-darwin modules without translation.

## Guardrails

- Mac is the active target; optimize for it first.
- Keep the flake root thin — inputs, overlays, system outputs, formatter, nothing else.
- Keep shared modules parameterized by `currentSystemUser` and `currentSystemUserHome`; the home path is computed once in `lib/mkSystem.nix`, never re-derived in host or Home Manager modules.
- Keep Home Manager from clobbering unmanaged config files without explicit migration intent (each new `programs.*` module must ship the activation-guard pattern from `modules/home/prompt.nix`).
- Keep brew variants disabled unless explicitly testing an escape hatch.
- Treat sample repos as references, never as active configuration.
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
