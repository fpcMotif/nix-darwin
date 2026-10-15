{
  description = "Per-project devShell that pins LSP server versions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system:
    let pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.default = pkgs.mkShell {
        # Shadow global LSP servers from modules/home/lsp.nix when editors and
        # agents launch inside this project's direnv shell.
        packages = with pkgs; [
          # === TypeScript / Vite stack ===
          nodejs_22
          bun # primary package manager
          typescript # `tsc --lsp` for TS 7 LSP
          oxlint # `oxlint --lsp` for lint
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

          # === Python ===
          python313
          basedpyright
          ruff
          uv
        ];

        shellHook = ''
          echo "devShell: pinned LSP servers loaded for $(pwd)" >&2
          # TS 7 native compiler version sanity check
          ${pkgs.typescript}/bin/tsc --version 2>/dev/null || true
        '';
      };
    });
}
