{ pkgs, lib, config, ... }:

# Single source of truth for language servers and LSP-related glue
# across every consumer:
#
#   - Claude Code CLI    → reads ~/.claude/lsp.json + enabled plugins
#                          from claude-plugins-official
#   - Codex CLI          → reads /etc/codex/config.toml `[lsp]` defaults
#   - Claude Desktop     → reads claude_desktop_config.json `mcpServers`
#                          (LSP wrapped via mcp-language-server)
#   - Codex App          → reads layered Codex `[mcp_servers]` configuration
#                          (same MCP bridge as Claude Desktop)
#   - Neovim             → built-in lsp client picks binaries from $PATH
#
# Modern Rust/Go-first TS stack:
#
#   tsc --lsp      →  TypeScript 7 native LSP (10-30x faster than
#                     tsserver). Provides hover/definitions/references/
#                     diagnostics for .ts/.tsx/.js/.jsx/.mts/.cts/.mjs/
#                     .cjs. TS 7 loads no tsserver plugins; Effect
#                     projects use @effect/tsgo, a TS 7 build with the
#                     Effect diagnostics compiled in.
#   oxlint --lsp   →  oxc-based linter LSP (Rust). Runs alongside tsc
#                     as a second LSP server for the same files. Vite
#                     ecosystem native (rolldown is also oxc-powered).
#
# Vite framework support: astro/svelte LSPs cover SFCs; emmet covers
# HTML completion; tailwind handles utility-class intellisense. Vue SFCs
# get oxlint diagnostics only — vue-language-server is deliberately not
# installed (nixpkgs builds it via pnpm, and neither has an aarch64-darwin
# binary in cache.nixos.org, so it compiled locally on every bump).
#
# Versions are pinned by the flake; clients just call the binary name.
# Project-level `.lsp.json` and devShell flakes shadow at the project
# root (highest priority in Claude Code's config cascade).

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
    rust-analyzer

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

  # ~/.claude/lsp.json — user-global LSP config for Claude Code's
  # built-in LSP tool. Project-root `.lsp.json` overrides this.
  #
  # Plugin interaction:
  #   - claude-plugins-official's `typescript-lsp` plugin registers a
  #     `typescript` server-id using typescript-language-server. Our
  #     `tsc` server-id is different — both would run for .ts files.
  #     Disable the plugin in ~/.claude/settings.json if you want
  #     tsc to be the sole TS server (recommended).
  #   - `gopls-lsp`, `rust-analyzer-lsp`, `lua-lsp` plugins are
  #     congruent with our gopls/rust-analyzer/lua entries; leaving
  #     them enabled is harmless (same binary on PATH).
  #
  # Schema (verified from anthropics/claude-plugins-official marketplace.json):
  #   command, args, extensionToLanguage, optional: initializationOptions,
  #   settings, isLinter, startupTimeout. NOT supported: fileTypes,
  #   rootMarkers, restartOnCrash, maxRestarts.
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
  # We don't pre-bake per-workspace LSP→MCP bridges — that's per-project
  # and lives in templates/lsp-overrides/mcp-bridge.json. This activation
  # only guarantees the mcpServers object is present so the user can add
  # `lsp-<lang>` entries without losing surrounding preferences.
  # Darwin only; Linux configs should not create a no-op macOS path.
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
