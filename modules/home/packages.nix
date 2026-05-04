{ lib, pkgs, ... }:

let
  inherit (pkgs.stdenv) isDarwin;

  commonPackages = with pkgs; [
    # File ops and viewing.
    bat
    fd
    ripgrep
    eza
    dust
    tree

    # System/process inspection.
    procs
    bottom

    # Navigation/search.
    zoxide
    fzf
    ast-grep
    mgrep

    # Git and version control.
    git
    lazygit
    delta
    jujutsu

    # Shell UX and terminal tools.
    starship
    tmux
    zsh

    # Utilities.
    jq
    gh
    just
    bun
    nodejs_24
    neovim
    gnupg
    gnused
    shellcheck
    stylua
    cmake
    tree-sitter
    wget
    zig
  ];

  darwinPackages = with pkgs; [
    # GUI apps
    martin.raycast

    martin.gemini-cli-preview
    martin.sourcegraph-amp
    martin.droid
    martin.opencode
    martin.opencode-electron
    martin.mole
    codex
    nur.repos.charmbracelet.crush
    martin.pi-coding-agent
    martin.oh-my-pi
    # zed-editor itself is installed by programs.zed-editor.enable in zed.nix.
  ];
in
{
  home.packages = commonPackages ++ lib.optionals isDarwin darwinPackages;
}
