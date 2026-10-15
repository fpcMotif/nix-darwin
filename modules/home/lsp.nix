{ pkgs, lib, config, ... }:

# vue-language-server is skipped: with no aarch64-darwin cache hit, it
# compiled on every bump.

let
  inherit (lib) hm;

  homeDir = config.home.homeDirectory;
  codexLsp = import ../shared/codex-lsp.nix { inherit lib; };
  inherit (codexLsp) jsExtensions oxlintExtraExtensions tailwindExtensions;

  lspServers = with pkgs; [
    # === TypeScript / JavaScript — modern Rust/Go stack ===
    typescript # `tsc --lsp` — TS 7 native LSP
    oxlint # `oxlint --lsp` — oxc lint LSP
    typescript-language-server
    astro-language-server # Astro components (Vite-based)
    svelte-language-server # Svelte (Vite-based)
    tailwindcss-language-server # Utility-class intellisense
    emmet-language-server # HTML/CSS emmet completion

    # === Go ===
    gopls

    # === Rust ===
    # rust-analyzer ships in martin.rust-toolchain (packages.nix) to match
    # the compiler; a second copy would collide.

    # === Swift / iOS ===
    sourcekit-lsp

    # === Python ===
    basedpyright # types + hover + definitions
    ruff # `ruff server` — lint + format

    # === Lua ===
    lua-language-server

    # === MCP bridge for desktop apps ===
    mcp-language-server # wraps any LSP as an MCP server
  ];

  # ~/.claude/lsp.json for Claude Code's LSP tool. The `typescript-lsp` plugin
  # adds a second TS server; disable it to keep tsc alone. Unsupported keys:
  # fileTypes, rootMarkers, restartOnCrash, maxRestarts.
  claudeLspJson = pkgs.writeText "claude-lsp.json" (builtins.toJSON {
    lspServers = {
      # Primary TS intelligence — TS 7 native LSP.
      tsc = {
        command = "tsc";
        args = [ "--lsp" "--stdio" ];
        extensionToLanguage = jsExtensions;
      };

      # Linter — runs in parallel with tsc on the same files plus
      # Vite-ecosystem SFCs.
      oxlint = {
        command = "oxlint";
        args = [ "--lsp" ];
        extensionToLanguage = jsExtensions // oxlintExtraExtensions;
        isLinter = true;
      };

      # Astro components.
      astro = {
        command = "astro-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = { ".astro" = "astro"; };
      };

      # Svelte components.
      svelte = {
        command = "svelteserver";
        args = [ "--stdio" ];
        extensionToLanguage = { ".svelte" = "svelte"; };
      };

      # Tailwind utility-class intellisense across all frontend files.
      tailwindcss = {
        command = "tailwindcss-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = tailwindExtensions;
      };

      # Swift / iOS projects. Xcode remains the SDK owner; sourcekit-lsp is
      # the editor bridge.
      sourcekit = {
        command = "sourcekit-lsp";
        args = [ ];
        extensionToLanguage = { ".swift" = "swift"; };
      };

      # Python — basedpyright shadows pyright (drop-in CLI-compatible).
      pyright = {
        command = "basedpyright-langserver";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".py" = "python";
          ".pyi" = "python";
        };
      };

      ruff = {
        command = "ruff";
        args = [ "server" ];
        extensionToLanguage = {
          ".py" = "python";
          ".pyi" = "python";
        };
        isLinter = true;
      };
    };
  });

in
{
  home.packages = lspServers;

  # === Claude Code: declarative LSP config ===
  # Read-only Nix-managed file. Project-level `.lsp.json` at any repo
  # root still wins per Claude Code's config cascade.
  home.file.".claude/lsp.json".source = claudeLspJson;

  # === Claude Desktop / Codex App: ensure mcpServers key exists ===
  # Only the key, not the bridges: those are per-project
  # (templates/lsp-overrides/mcp-bridge.json).
  home.activation.claudeDesktopMcpScaffold =
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      hm.dag.entryAfter [ "writeBoundary" ] ''
        target="${homeDir}/Library/Application Support/Claude/claude_desktop_config.json"

        if [ ! -f "$target" ]; then
          :
        elif ${pkgs.jq}/bin/jq -e '.mcpServers' "$target" >/dev/null 2>&1; then
          :
        elif [ -n "''${DRY_RUN:-}" ]; then
          echo "claude-desktop: would scaffold empty mcpServers in $target" >&2
        else
          tmp=$(${pkgs.coreutils}/bin/mktemp)
          ${pkgs.jq}/bin/jq '. + { mcpServers: (.mcpServers // {}) }' \
            "$target" > "$tmp" && ${pkgs.coreutils}/bin/mv "$tmp" "$target"
          echo "claude-desktop: scaffolded empty mcpServers in $target" >&2
        fi
      ''
    );
}
