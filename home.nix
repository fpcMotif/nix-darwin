{ pkgs, ... }:

# Per-user (home-manager) packages for martinfan.
#
# Strategy: Nix owns the *binaries* the dotfiles reference; chezmoi keeps
# owning the actual config files (rc.d/, starship.toml, ghostty config,
# ~/.claude, ~/.pi). So we deliberately do NOT enable programs.zsh /
# programs.starship / etc. here — that would clobber chezmoi-managed files.
#
# If you ever decide to migrate config files to Nix too, flip the relevant
# `programs.<tool>.enable = true;` and remove the chezmoi version.

let
  # gemini-cli @preview — see ./pkgs/gemini-cli-preview.nix for the full
  # derivation and bump procedure.
  gemini-cli-preview = pkgs.callPackage ./pkgs/gemini-cli-preview.nix { };

  # pi-coding-agent (`pi`) and oh-my-pi (`omp`) — Bun-compiled standalone
  # binaries fetched from upstream GitHub releases. Each derivation file
  # documents why we use the prebuilt binary over buildNpmPackage, and the
  # bump procedure (one curl + one nix-prefetch-url + one hash convert).
  pi-coding-agent = pkgs.callPackage ./pkgs/pi-coding-agent.nix { };
  oh-my-pi        = pkgs.callPackage ./pkgs/oh-my-pi.nix { };

  # Pi can be told which npm-compatible command to use for package installs.
  # Prefer Bun for the hot path, but keep a Nix-provided npm fallback for
  # npm-specific metadata commands that Bun does not emulate exactly.
  pi-npm-bun = pkgs.writeShellScriptBin "pi-npm-bun" ''
    set -euo pipefail

    bun=${pkgs.bun}/bin/bun
    npm=${pkgs.nodejs_24}/bin/npm
    bun_install="''${BUN_INSTALL:-$HOME/.bun}"

    case "''${1:-}" in
      root)
        if [ "''${2:-}" = "-g" ] || [ "''${2:-}" = "--global" ]; then
          printf '%s\n' "$bun_install/install/global/node_modules"
          exit 0
        fi
        ;;
      bin)
        if [ "''${2:-}" = "-g" ] || [ "''${2:-}" = "--global" ]; then
          exec "$bun" pm bin -g
        fi
        ;;
      install|i)
        shift
        if [ "''${1:-}" = "-g" ] || [ "''${1:-}" = "--global" ]; then
          shift
          exec "$bun" add -g "$@"
        fi
        exec "$bun" install "$@"
        ;;
      uninstall|remove|rm)
        shift
        if [ "''${1:-}" = "-g" ] || [ "''${1:-}" = "--global" ]; then
          shift
        fi
        exec "$bun" remove "$@"
        ;;
      update|upgrade)
        shift
        if [ "''${1:-}" = "-g" ] || [ "''${1:-}" = "--global" ]; then
          shift
          exec "$bun" update -g "$@"
        fi
        exec "$bun" update "$@"
        ;;
      view|info)
        shift
        exec "$bun" pm view "$@"
        ;;
      --version|-v)
        exec "$bun" --version
        ;;
    esac

    exec "$npm" "$@"
  '';
in
{
  home.username = "martinfan";
  home.homeDirectory = "/Users/martinfan";

  # Pin the home-manager schema we wrote against. Bumping this is a
  # deliberate one-time chore; do NOT auto-track unstable.
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    # File ops & viewing (aliased in dot_config/zsh/rc.d/30-aliases.zsh)
    bat              # cat replacement
    fd               # find replacement
    ripgrep          # grep replacement (rg)
    eza              # ls replacement
    dust             # du replacement
    tree             # used as fallback / direct invocation

    # System / process
    procs            # ps replacement
    bottom           # top replacement (btm)

    # Navigation / search
    zoxide           # smart cd (z)
    fzf              # fuzzy finder
    ast-grep         # AST-aware code search (sg)
    mgrep            # semantic / mixedbread grep

    # Git
    lazygit          # git TUI (lg)
    delta            # git pager (referenced in dot_config/git/config)

    # Shell UX
    starship         # prompt (initialized in rc.d/00-init.zsh)
    sheldon          # zsh plugin manager (used by rc.d/00-init.zsh)

    # Utilities
    jq               # JSON tooling, used by climode.json checks
    gh               # GitHub CLI
    chezmoi          # config-file layer for dotfiles (~/.pi, ~/.claude, zsh)
    just             # task runner used by ~/.pi/agent/justfile
    bun              # fast JS runtime/package manager for Pi extensions
    nodejs_24        # npm fallback for Pi package metadata compatibility

    # AI coding agents (moved here from environment.systemPackages — these
    # are user-level dev tools, not system-wide infrastructure)
    gemini-cli-preview  # Google Gemini CLI @preview (override above)
    codex               # OpenAI Codex CLI
    crush               # Charmbracelet Crush (TUI agent, nixpkgs)
    pi-coding-agent     # @mariozechner/pi-coding-agent — binary `pi`
    oh-my-pi            # can1357/oh-my-pi fork           — binary `omp`
    pi-npm-bun          # npm-compatible Bun wrapper for Pi package installs
  ];
}
