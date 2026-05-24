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
    rtk
    bun
    nodejs_25
    # Frontend and SSO/OIDC helpers. OXC is the formatter/linter stack;
    # oxlint lives in ./lsp.nix because it also runs as an LSP server.
    oxfmt
    # Keep Wrangler's vendored TypeScript below the first-party TypeScript
    # package in the Home Manager buildEnv.
    (lib.lowPrio wrangler)
    mkcert
    jwt-cli
    step-cli
    xh

    neovim
    gnupg
    gnused
    shellcheck
    stylua
    # Rust.
    rustc
    cargo
    rustfmt
    clippy
    cargo-nextest
    cargo-watch
    cargo-edit

    # Go.
    go
    gofumpt
    golangci-lint

    # Haskell.
    ghc
    cabal-install
    fourmolu
    hlint
    ghcid

    # All language servers live in ./lsp.nix — including typescript-go
    # (it's both compiler and `tsgo --lsp` server), oxlint, vtsls,
    # vue/astro/svelte/tailwind/emmet servers, gopls, rust-analyzer,
    # sourcekit-lsp, haskell-language-server, basedpyright, ruff,
    # lua-language-server, mcp-language-server.
    cmake
    tree-sitter
    wget
    zig
  ];

  darwinPackages = with pkgs; [
    # Darwin-only GUI apps and Apple-platform CLIs.
    martin.raycast
    # iOS / Apple platform CLIs. Xcode itself stays Apple-managed; these are
    # the shell tools around project generation, signing flows, and CI logs.
    cocoapods
    fastlane
    xcodes
    xcbeautify
    swiftformat
    swiftlint

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
