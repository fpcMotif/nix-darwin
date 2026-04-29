{ lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;

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
    chezmoi
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
    martin.gemini-cli-preview
    martin.sourcegraph-amp
    codex
    crush
    martin.pi-coding-agent
    martin.oh-my-pi
    martin.pi-npm-bun
  ];
in
{
  home.packages = commonPackages ++ lib.optionals isDarwin darwinPackages;
}
