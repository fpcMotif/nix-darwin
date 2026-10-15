{ lib, pkgs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  commonPackages = with pkgs; [
    # File ops and viewing.
    bat
    fd
    ripgrep
    eza
    fcp
    dust
    tree

    # System/process inspection.
    procs
    bottom

    # Navigation/search.
    zoxide
    fzf
    ast-grep
    martin.fff-mcp

    # Git and version control.
    git
    delta
    jujutsu
    martin.calldiff

    # Shell UX and terminal tools.
    starship
    tmux
    zsh

    # Utilities.
    jq
    gh
    just
    # bun comes from `martin.bun-canary-bin` (canary channel) in darwinPackages
    # below — nixpkgs `bun` would collide on $out/bin/bun, so it's not listed.
    # node only (bun replaces npm); _26 is the floor, see scripts/update-flake-inputs.sh.
    nodejs-slim_26
    # Frontend and SSO/OIDC helpers. OXC is the formatter/linter stack;
    # oxlint lives in ./lsp.nix because it also runs as an LSP server.
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
    # Rust.
    martin.rust-toolchain
    cargo-nextest
    # bacon replaces cargo-watch, which is archived, uncached, and crashes ld.
    bacon
    cargo-edit

    # Go.
    go
    gofumpt
    golangci-lint

    # Python.
    uv

    # All language servers, typescript included, live in ./lsp.nix.
    cmake
    tree-sitter
    wget
    zig
  ];

  darwinPackages = with pkgs; [
    # iOS / Apple platform CLIs. Xcode itself stays Apple-managed; these are
    # the shell tools around project generation, signing flows, and CI logs.
    cocoapods
    fastlane
    xcodes
    xcbeautify
    swiftformat
    swiftlint

    # bun, canary channel. Replaces nixpkgs `bun` (removed from commonPackages)
    # because `bun upgrade` can't write into the read-only /nix/store.
    martin.bun-canary-bin
    martin.sourcegraph-amp
    martin.droid
    martin.opencode
    # Hunk, prebuilt release: review-first TUI diff viewer the Git section of
    # CLAUDE.md routes human review to (nixpkgs `hunk` SIGKILLs here, see pkgs/hunk-bin.nix).
    martin.hunk-bin
    martin.mole
    codex
    nur.repos.charmbracelet.crush
    martin.pi-coding-agent
    martin.oh-my-pi
    martin.nub # Bun-rival toolkit on stock node (nubjs/nub).
    martin.drafts-mcp-server
    martin.jev-traits
    # zed-editor itself is installed by programs.zed-editor.enable in zed.nix.
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
