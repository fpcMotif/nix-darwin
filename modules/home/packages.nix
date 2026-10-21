{ lib, pkgs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  commonPackages = with pkgs; [
    bat
    fd
    ripgrep
    eza
    fcp
    dust
    tree
    procs
    bottom
    zoxide
    fzf
    ast-grep
    martin.fff-mcp
    git
    delta
    jujutsu
    martin.calldiff
    starship
    tmux
    zsh
    jq
    gh
    just
    # Omit nixpkgs bun here because martin.bun-canary-bin provides bin/bun on
    # Darwin. _26 is the floor; see scripts/update-flake-inputs.sh.
    nodejs-slim_26
    # oxlint and language servers live in ./lsp.nix.
    oxfmt
    mkcert
    jwt-cli
    step-cli
    hyperfine
    neovim
    gnupg
    gnused
    shellcheck
    stylua
    martin.rust-toolchain
    cargo-nextest
    # cargo-watch is archived, uncached, and crashes ld.
    bacon
    cargo-edit
    go
    gofumpt
    golangci-lint
    martin.uv-bin
    cmake
    tree-sitter
    wget
    zig
  ];

  darwinPackages = with pkgs; [
    # Xcode stays Apple-managed; these CLIs cover project generation, signing, and CI logs.
    cocoapods
    fastlane
    xcodes
    xcbeautify
    swiftformat
    swiftlint

    # Canary prebuilt replaces nixpkgs bun because bun upgrade cannot write into /nix/store.
    martin.bun-canary-bin
    martin.sourcegraph-amp
    martin.droid
    martin.opencode
    # Prebuilt release because nixpkgs hunk crashes with SIGKILL on Darwin.
    martin.hunk-bin
    martin.mole
    codex
    nur.repos.charmbracelet.crush
    martin.pi-coding-agent
    martin.oh-my-pi
    martin.nub
    martin.drafts-mcp-server
    martin.traits
  ];
in
{
  home.packages = commonPackages ++ lib.optionals isDarwin darwinPackages;

  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Macchiato";
    };
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = false;
  };
}
