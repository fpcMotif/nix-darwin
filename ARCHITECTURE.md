# Nix Architecture

This repository is Martin's cross-platform Nix configuration. The active production target is the Mac; Linux/Omakub and NixOS targets are deliberately staged behind it.

## Target Priority

1. **Active:** `darwinConfigurations.Martins-Mac-mini`
   - Apple Silicon nix-darwin system.
   - Primary place to make this repo excellent.
2. **Future:** `homeConfigurations.martinfan-omakub`
   - Planned Home Manager profile for Ubuntu/Omakub (<https://omakub.org/>).
   - Documentation/design target only for now; no flake output yet.
3. **Inactive scaffolds:** `nixosConfigurations.wsl` and `nixosConfigurations.x230`
   - Kept as future NixOS/WSL experiments.
   - They are not the main product until evaluated on real Nix systems.

## Current Live Layout

```text
.
├── flake.nix                 # thin flake entry point
├── lib/mkSystem.nix          # shared Darwin/NixOS system constructor
├── hosts/
│   ├── darwin/default.nix    # Martins-Mac-mini host layer
│   ├── wsl/default.nix       # inactive NixOS-WSL scaffold
│   └── x230/default.nix      # inactive ThinkPad scaffold
├── modules/
│   ├── options.nix           # cross-platform martin.* options
│   ├── darwin/               # nix-darwin shared modules
│   ├── nixos/                # inactive shared NixOS module
│   └── home/                 # Martin's Home Manager profile
├── pkgs/                     # custom package derivations/overlay
├── references/               # external sample repos, reference-only
├── home.nix                  # compatibility shim
└── skills.nix                # compatibility shim
```

`flake.nix` should stay thin: it wires inputs, overlays, systems, and formatters. Host- and feature-specific behavior belongs in `hosts/` and `modules/`.

## Composition Model

`lib/mkSystem.nix` is the central constructor. Each system supplies:

- `name` — flake output/system name
- `system` — platform triple, e.g. `aarch64-darwin`
- `user` — current Martin user for that host
- `platform` — `darwin` or `nixos`
- `hostModule` — host-specific module path

The constructor:

1. selects nix-darwin or NixOS,
2. applies the shared overlay from `pkgs/default.nix`,
3. imports shared platform modules,
4. wires Home Manager as a system module,
5. passes `currentSystem`, `currentSystemName`, and `currentSystemUser` through `specialArgs`.

Shared modules should use `currentSystemUser` instead of hardcoding `martinfan`. The profile is still Martin-specific; it is not a generic multi-user framework.

## System vs Home vs Dotfiles Boundary

Three layers, one writer per concern:

| Layer | Tool | Owns |
|---|---|---|
| System | nix-darwin / NixOS | OS settings, users, shells, services, system apps |
| User packages | Home Manager | per-user CLI/dev packages and activation scripts |
| Config text | chezmoi/dotfiles | zsh, git, starship, editor, terminal, agent config files |

Home Manager intentionally installs binaries such as `starship`, `sheldon`, `git`, `bat`, `fd`, `rg`, etc. It does **not** currently enable Home Manager program modules for shell/git/starship because those config files are managed elsewhere. Avoid two tools writing the same file.

If a config file is ever migrated from chezmoi to Nix, do it one file at a time:

1. stop tracking it in chezmoi,
2. remove the live unmanaged file,
3. enable the relevant Home Manager `programs.*` module,
4. rebuild and verify.

## Darwin Modules

Darwin shared logic is split modestly:

```text
modules/darwin/
├── default.nix         # imports the Darwin module set and base nixpkgs config
├── nix.nix             # flakes/nix-command and trusted users
├── shell.nix           # zsh shell registration
├── security.nix        # Touch ID sudo
└── brew-variants.nix   # dormant brew-family scaffolds
```

The active Darwin host lives in `hosts/darwin/default.nix` and sets:

- the current user's macOS home directory,
- `system.primaryUser`,
- `system.stateVersion`,
- system GUI packages from `pkgs.martin`.

## Home Manager Modules

Home Manager is Martin-specific but parameterized by `currentSystemUser`:

```text
modules/home/
├── default.nix         # username, homeDirectory, stateVersion, imports
├── packages.nix        # common and Darwin-only packages
└── skills.nix          # agent skill bundle activation
```

Common packages should be portable across Mac, future Omakub Home Manager, and NixOS where practical. Darwin-only packages belong behind `pkgs.stdenv.isDarwin` checks.

## Agent Skills Nix Setup

The active skills module is `modules/home/skills.nix`. It currently uses `inputs.agent-skills.lib.agent-skills` directly to discover selected `SKILL.md` directories, build one Nix store bundle, and sync that bundle to:

- `$HOME/.pi/agent/skills` for Oh My Pi / Pi harness skills,
- `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills` for Claude Code personal skills,
- `$HOME/.agents/skills` as the vendor-neutral shared user skill registry.

This one-file library setup is acceptable while the target matrix is small, but the preferred universal shape for broader Codex/Claude/Cursor coverage is the upstream Home Manager DSL from `agent-skills-nix`:

```nix
imports = [ inputs.agent-skills.homeManagerModules.default ];

programs.agent-skills = {
  enable = true;

  sources.<name> = {
    input = "<flake-input-name>";
    subdir = "skills";
    # Use idPrefix when two sources expose the same skill name.
    # idPrefix = "openai";
    filter.maxDepth = null;
  };

  # Prefer explicit allowlists for third-party skill repos.
  skills.enable = [ "skill-a" "skill-b" ];
  # Use enableAll only for tightly trusted private sources.
  # skills.enableAll = [ "private" ];

  targets = {
    agents.enable = true; # $HOME/.agents/skills: shared Open Agent Skills registry
    claude.enable = true; # ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills
    cursor.enable = true; # $HOME/.cursor/skills
    codex.enable = true;  # ${CODEX_HOME:-$HOME/.codex}/skills, useful as a compatibility mirror
  };
};
```

Universal policy: publish the same bundle once, then mirror it to each agent-native directory that has documented skill discovery. `$HOME/.agents/skills` is the first-class shared target because Codex documents it for user skills and Cursor documents it as a user-level skills directory. Claude Code still documents `~/.claude/skills`, so keep a Claude-specific mirror. Cursor also documents `~/.cursor/skills` and compatibility loading from `.claude` and `.codex`; mirroring to Cursor is optional if `$HOME/.agents/skills` already works, but useful when debugging tool-specific discovery.

Project-local skills should be a separate decision from user-global skills. Use the upstream `mkLocalInstallScript` or `mkShellHook` with `defaultLocalTargets` when a repository should receive checked-in or dev-shell-installed skills under `.agents/skills`, `.claude/skills`, `.cursor/skills`, or `.codex/skills`. Use `copy-tree` for local targets so a project can inspect/edit generated files without following Nix store symlinks; use `symlink-tree` for global Home Manager targets. Avoid `link` when the destination uses shell variables such as `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` because `home.file` cannot expand them at activation time.

Zed and VS Code are not equivalent skill targets today. Zed's published AI docs document `.rules`, `.cursorrules`, `AGENTS.md`, `CLAUDE.md`, and related rule files; Agent Skills support is visible in an open upstream PR, not a stable documented target. VS Code Copilot documents `AGENTS.md`, `.github/copilot-instructions.md`, and `.github/instructions/*.instructions.md`, not `SKILL.md` directories. For those editors, keep shared instructions in `AGENTS.md` and add editor-native rule/instruction files only when needed; do not invent Nix skill mirrors until the editor documents a stable skills path.

Skill authoring rules: follow the Agent Skills spec (`SKILL.md` with `name` and `description` frontmatter), keep each skill focused, namespace duplicate upstream IDs with `idPrefix`, keep recursive discovery enabled unless a source is known to be flat-only, and keep `excludePatterns = [ "/.system" ]` unless Nix must own every file in the target directory. Use `skills.explicit.<name>.packages` and `transform` when a skill needs Nix-provided tools; this keeps dependencies bundled as local paths inside the skill and avoids global package assumptions.

## Package Ownership

Default policy: **pure Nix first**.

- CLI/dev tools: `modules/home/packages.nix`
- Important Mac GUI apps: custom derivations in `pkgs/`, exposed as `pkgs.martin.*`
- System-level Mac apps currently include Dropbox, Google Drive, and Raycast
- Agent/dev tools such as Gemini preview, Amp, Pi, and Oh My Pi are custom packaged in `pkgs/`

Avoid duplicate ownership. A tool should not be installed simultaneously through Nix and a brew variant unless it is a temporary migration step.

## Homebrew / zerobrew / zigbrew Policy

Brew-family tools are represented as actual Darwin options, but they are dormant guardrails, not the default package manager:

```nix
martin.brew.homebrew.enable = false;
martin.brew.zerobrew.enable = false;
martin.brew.zigbrew.enable = false;
```

Policy:

- target Homebrew usage is effectively zero,
- prefer Nix/custom derivations for declarative apps,
- Homebrew is only an emergency/ad-hoc scaffold,
- zerobrew and zigbrew are documentation-only scaffolds for now,
- never use Homebrew `cleanup = "zap"` unless every cask you care about is declaratively owned.

If `martin.brew.homebrew.enable` is explicitly enabled, nix-darwin's Homebrew integration uses `onActivation.cleanup = "none"` to avoid destructive cleanup.

## Linux / Omakub Plan

Omakub is Ubuntu-focused, so it should not become a `nixosConfigurations.*` output. The likely future shape is a standalone Home Manager output such as:

```nix
homeConfigurations.martinfan-omakub
```

Do not add that output until these are known:

- exact Linux architecture,
- username and home path,
- whether Nix is single-user or multi-user,
- which packages should be shared with the Mac,
- which dotfiles remain chezmoi-owned.

Until then, Omakub is a design target documented here only.

## WSL and X230 Scaffolds

`wsl` and `x230` remain in the flake as inactive NixOS scaffolds. They are useful for future experimentation and possible Windows-app testing/linting workflows, but they are lower priority than Mac and future Omakub Home Manager.

Do not assume they are production-ready until they have been evaluated on real Nix systems.

## Reference Repositories

`references/` contains external sample codebases kept for learning:

- `references/nix-config-kyura/`
- `references/nixos-config-mitchellh/`
- `references/agent-skills-nix-master/`

They are not active inputs and are not imported by this flake. Borrow patterns selectively:

- from Kyura: program/package splits, Darwin defaults, font/app examples, overlays,
- from Mitchellh: simple `mkSystem`, machine/user/home separation, pragmatic WSL/VM scaffolding,
- from Agent Skills Nix: Home Manager DSL, target syncing, local install scripts, and skill packaging patterns.

Do not copy Linux-specific NixOS concepts into nix-darwin modules without translation. Do not migrate `modules/home/skills.nix` to the Agent Skills Home Manager DSL until that is a deliberate follow-up change.

## Workflows

### Build/check the active Mac config

```bash
darwin-rebuild build --flake .#Martins-Mac-mini
sudo darwin-rebuild switch --flake .#Martins-Mac-mini
```

### Add a CLI tool

1. Add portable tools to `modules/home/packages.nix` common packages.
2. Add Darwin-only tools under the Darwin package list.
3. Build first, then switch.

### Add a Mac GUI app

1. Prefer a custom derivation in `pkgs/<name>.nix`.
2. Expose it from `pkgs/default.nix` under `pkgs.martin.<name>`.
3. Add it to `hosts/darwin/default.nix` if it is system-level.

### Update inputs

```bash
nix flake update
darwin-rebuild build --flake .#Martins-Mac-mini
sudo darwin-rebuild switch --flake .#Martins-Mac-mini
```

## Current Guardrails

- Mac is the active target; optimize for it first.
- Keep the flake root thin.
- Keep shared modules parameterized by `currentSystemUser`.
- Keep Home Manager from clobbering chezmoi-owned config files.
- Keep brew variants disabled unless explicitly testing an escape hatch.
- Treat sample repos as references, not active configuration.
