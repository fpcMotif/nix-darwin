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

    # Git.
    git
    lazygit
    delta

    # Shell UX. Config files remain chezmoi-owned.
    starship
    sheldon

    # Utilities.
    jq
    gh
    chezmoi
    just
    bun
    nodejs_24
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
