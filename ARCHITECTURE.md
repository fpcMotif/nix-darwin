# Nix Architecture — Martin's cross-platform config

> **Active target:** `darwinConfigurations.Martins-Mac-mini` (Apple Silicon, nix-darwin).
> **Last reviewed:** 2026-04-28.

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

| Layer          | Tool                | Owns                                                          |
|----------------|---------------------|---------------------------------------------------------------|
| System         | nix-darwin / NixOS  | OS settings, users, shells, services, system apps             |
| User packages  | Home Manager        | per-user CLI/dev packages, activation scripts                 |
| Config text    | chezmoi / dotfiles  | zsh, git, starship, editor, terminal, agent config files      |

Home Manager intentionally installs binaries (`starship`, `sheldon`, `git`, `bat`, `fd`, `rg`, …) **without** enabling the matching `programs.<tool>` modules, because those config files are managed by chezmoi. This keeps Nix from clobbering chezmoi-owned files.

### Migrating a config file from chezmoi to Nix

Do this one file at a time:

1. Stop tracking the file in chezmoi.
2. Remove the live unmanaged file from `$HOME`.
3. Enable the relevant Home Manager `programs.*` module.
4. Rebuild and verify ownership.

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
├── default.nix         # imports the Darwin module set + base nixpkgs config
├── nix.nix             # flakes / nix-command / trusted users
├── shell.nix           # zsh shell registration
├── security.nix        # Touch ID sudo
└── brew-variants.nix   # dormant brew-family scaffolds (see policy below)
```

The active Darwin host (`hosts/darwin/default.nix`) sets:

- the current user's macOS home directory,
- `system.primaryUser`,
- `system.stateVersion`,
- system-level GUI packages from `pkgs.martin`.

`system.stateVersion` is set once per host and is **not** bumped casually — bumping it opts into nix-darwin's newer defaults, which is independent of upgrading nixpkgs.

## Home Manager modules

```text
modules/home/
├── default.nix         # username, homeDirectory, stateVersion, imports
├── packages.nix        # common + Darwin-only packages
└── skills.nix          # agent skill bundle activation
```

Common packages should be portable across Mac, future Omakub Home Manager, and NixOS where practical. Darwin-only packages live behind `pkgs.stdenv.isDarwin` checks.

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

Omakub is Ubuntu-focused, so it should not become a `nixosConfigurations.*` output. The likely future shape is a standalone Home Manager output:

```nix
homeConfigurations.martinfan-omakub
```

Do not add that output until these are settled:

- exact Linux architecture,
- username and home path,
- whether Nix is single-user or multi-user,
- which packages are shared with the Mac,
- which dotfiles remain chezmoi-owned.

Until then, Omakub is a design target documented here only.

## WSL and X230 scaffolds

`wsl` and `x230` remain in the flake as inactive NixOS scaffolds. They are useful for future experimentation — Windows-app testing, NixOS-on-laptop experiments — but they are lower priority than Mac and future Omakub.

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
- Keep shared modules parameterized by `currentSystemUser`.
- Keep Home Manager from clobbering chezmoi-owned config files.
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
