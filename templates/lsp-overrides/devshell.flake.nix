{
  description = "Per-project devShell that pins LSP server versions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Pin Rust toolchain (uncomment for nightly):
    # rust-overlay.url = "github:oxalica/rust-overlay";
    # rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        # Servers listed here shadow whatever's in
        # ~/nix-config/modules/home/lsp.nix while inside this devShell.
        # Use direnv (`use flake` in .envrc) so Claude Code, Codex CLI,
        # and Neovim all inherit this PATH whenever they're launched
        # from this project.
        packages = with pkgs; [
          # === TypeScript / Vite stack ===
          nodejs_22
          bun # primary package manager
          typescript-go # `tsgo --lsp` for TS 7 LSP
          oxlint # `oxlint --lsp` for lint
          vtsls # tsserver wrapper, plugin-capable
          vue-language-server # Vite + Vue
          astro-language-server # Vite + Astro
          svelte-language-server # Vite + Svelte
          tailwindcss-language-server # utility-class intellisense
          emmet-language-server # HTML emmet

          # === Go ===
          go
          gopls

          # === Rust ===
          rust-analyzer
          # (rust-bin.nightly.latest.default.override {
          #   extensions = [ "rust-src" "rust-analyzer" ];
          # })

          # === Python ===
          python313
          basedpyright
          ruff
          uv
        ];

        shellHook = ''
          echo "devShell: pinned LSP servers loaded for $(pwd)" >&2
          # tsgo version sanity check
          ${pkgs.typescript-go}/bin/tsgo --version 2>/dev/null || true
        '';
      };
    });
}
