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
    martin.fff-mcp

    # Git and version control.
    git
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
    # bun comes from `martin.bun-canary-bin` (canary channel) in darwinPackages
    # below — nixpkgs `bun` would collide on $out/bin/bun, so it's not listed.
    # node runtime only (no bundled npm — we use bun). Pinned to the newest
    # LTS-line runtime; _26 = 26.5.0 is darwin-cached as of 2026-07 (was
    # uncached at 26.3.1, which forced the old _24 pin).
    nodejs-slim_26
    # Frontend and SSO/OIDC helpers. OXC is the formatter/linter stack;
    # oxlint lives in ./lsp.nix because it also runs as an LSP server.
    oxfmt
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
    # bacon replaces cargo-watch: upstream archived it (points to bacon/watchexec),
    # and at the 2026-07 pin it is uncached AND its link step deterministically
    # crashes cctools ld (SIGTRAP) — it would re-break `just switch` after every
    # nightly flake bump. bacon is darwin-cached.
    bacon
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

    # bun, canary channel. Replaces nixpkgs `bun` (removed from commonPackages)
    # because `bun upgrade` can't write into the read-only /nix/store.
    martin.bun-canary-bin
    martin.sourcegraph-amp
    martin.droid
    martin.opencode
    martin.opencode-electron
    martin.mole
    codex
    nur.repos.charmbracelet.crush
    martin.pi-coding-agent
    martin.oh-my-pi
    martin.nub # Bun-rival toolkit on stock node (nubjs/nub).
    # martin.trail  # TEMP-DISABLED: trail.nix uses an eval-time `builtins.fetchGit`
    # of the PRIVATE repo, which fails under `sudo darwin-rebuild switch` (root has
    # neither your git CA certs nor your GitHub auth). Re-enable once trail fetches
    # without per-user creds — e.g. nix `access-tokens` set system-wide + a github:
    # fetcher, a public repo, or install it via `uv` from ~/devv/trail instead.
    # zed-editor itself is installed by programs.zed-editor.enable in zed.nix.
  ];
in
{
  home.packages = commonPackages ++ lib.optionals isDarwin darwinPackages;
}
