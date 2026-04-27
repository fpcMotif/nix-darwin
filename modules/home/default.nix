{ lib, pkgs, ... }:

let
  isDarwin = pkgs.stdenv.isDarwin;
  homeDirectory =
    if isDarwin then
      "/Users/martinfan"
    else
      "/home/martinfan";

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

    # Shell UX.
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
  imports = [
    ./skills.nix
  ];

  home = {
    username = "martinfan";
    inherit homeDirectory;

    # Pin the Home Manager schema we wrote against. Bump deliberately.
    stateVersion = "24.05";

    packages = commonPackages ++ lib.optionals isDarwin darwinPackages;
  };
}
