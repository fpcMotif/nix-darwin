{ pkgs, lib, config, ... }:

# Single source of truth for language servers and LSP-related glue
# across every consumer:
#
#   - Claude Code CLI    → reads ~/.claude/lsp.json + enabled plugins
#                          from claude-plugins-official
#   - Codex CLI          → reads ~/.codex/config.toml `[lsp]` block
#   - Claude Desktop     → reads claude_desktop_config.json `mcpServers`
#                          (LSP wrapped via mcp-language-server)
#   - Codex App          → reads ~/.codex/config.toml `[mcp_servers]`
#                          (same MCP bridge as Claude Desktop)
#   - Neovim             → built-in lsp client picks binaries from $PATH
#
# Modern Rust/Go-first TS stack:
#
#   tsgo --lsp     →  TypeScript 7 beta native LSP (10-30x faster than
#                     tsserver). Provides hover/definitions/references/
#                     diagnostics for .ts/.tsx/.js/.jsx/.mts/.cts/.mjs/
#                     .cjs. Effect-TS plugins load via tsconfig.json
#                     compilerOptions.plugins in interactive mode.
#   oxlint --lsp   →  oxc-based linter LSP (Rust). Runs alongside tsgo
#                     as a second LSP server for the same files. Vite
#                     ecosystem native (rolldown is also oxc-powered).
#   vtsls          →  Fallback drop-in tsserver wrapper kept for the
#                     rare projects that need tsserver plugins not yet
#                     supported by tsgo. Opt-in via per-project .lsp.json.
#
# Vite framework support: vue/astro/svelte LSPs cover SFCs; emmet covers
# HTML completion; tailwind handles utility-class intellisense.
#
# Versions are pinned by the flake; clients just call the binary name.
# Project-level `.lsp.json` and devShell flakes shadow at the project
# root (highest priority in Claude Code's config cascade).

let
  inherit (lib) hm;

  homeDir = config.home.homeDirectory;

  lspServers = with pkgs; [
    # === TypeScript / JavaScript — modern Rust/Go stack ===
    typescript-go               # `tsgo --lsp` — TS 7 native LSP
    oxlint                      # `oxlint --lsp` — oxc lint LSP
    vtsls                       # tsserver wrapper, opt-in fallback
    # Compat: `typescript-lsp@claude-plugins-official` plugin still
    # spawns `typescript-language-server`, and vtsls reads tsserver
    # from a `typescript` package. Keeping both here is cheap and
    # avoids breakage when a project pins to the legacy tsserver.
    typescript
    typescript-language-server
    vue-language-server         # Vue SFCs (Vite + Vue)
    astro-language-server       # Astro components (Vite-based)
    svelte-language-server      # Svelte (Vite-based)
    tailwindcss-language-server # Utility-class intellisense
    emmet-language-server       # HTML/CSS emmet completion

    # === Go ===
    gopls

    # === Rust ===
    rust-analyzer

    # === Python ===
    basedpyright                # types + hover + definitions
    ruff                        # `ruff server` — lint + format

    # === Lua ===
    lua-language-server

    # === MCP bridge for desktop apps ===
    mcp-language-server         # wraps any LSP as an MCP server
  ];

  # Common JS/TS extension → language-id map used by tsgo, oxlint, and
  # vtsls. Kept as a Nix attrset so all servers share one definition.
  jsExtensions = {
    ".ts"  = "typescript";
    ".tsx" = "typescriptreact";
    ".mts" = "typescript";
    ".cts" = "typescript";
    ".js"  = "javascript";
    ".jsx" = "javascriptreact";
    ".mjs" = "javascript";
    ".cjs" = "javascript";
  };

  # Extra extensions oxlint handles natively that tsgo does not.
  oxlintExtraExtensions = {
    ".vue"   = "vue";
    ".astro" = "astro";
    ".svelte" = "svelte";
  };

  # Render an attrset's keys as a TOML string array. Lets the Codex
  # config below stay in sync with the Nix-side extension maps without
  # hand-listing extensions twice.
  tomlExts = attrs: lib.concatMapStringsSep ", " (e: ''"${e}"'') (builtins.attrNames attrs);

  jsExtsToml = tomlExts jsExtensions;
  jsAndVueExtsToml = tomlExts (jsExtensions // oxlintExtraExtensions);
  tailwindExtsToml = tomlExts (jsExtensions // oxlintExtraExtensions // {
    ".html" = "html";
    ".css"  = "css";
  });

  # ~/.claude/lsp.json — user-global LSP config for Claude Code's
  # built-in LSP tool. Project-root `.lsp.json` overrides this.
  #
  # Plugin interaction:
  #   - claude-plugins-official's `typescript-lsp` plugin registers a
  #     `typescript` server-id using typescript-language-server. Our
  #     `tsgo` server-id is different — both would run for .ts files.
  #     Disable the plugin in ~/.claude/settings.json if you want
  #     tsgo to be the sole TS server (recommended).
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
      # Primary TS intelligence — TS 7 / tsgo native LSP.
      tsgo = {
        command = "tsgo";
        args = [ "--lsp" "--stdio" ];
        extensionToLanguage = jsExtensions;
      };

      # Linter — runs in parallel with tsgo on the same files plus
      # Vite-ecosystem SFCs.
      oxlint = {
        command = "oxlint";
        args = [ "--lsp" ];
        extensionToLanguage = jsExtensions // oxlintExtraExtensions;
        isLinter = true;
      };

      # Vite + Vue Single-File Components.
      vue = {
        command = "vue-language-server";
        args = [ "--stdio" ];
        extensionToLanguage = { ".vue" = "vue"; };
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
        extensionToLanguage = jsExtensions // oxlintExtraExtensions // {
          ".html"   = "html";
          ".css"    = "css";
        };
      };

      # Python — basedpyright shadows pyright (drop-in CLI-compatible).
      pyright = {
        command = "basedpyright-langserver";
        args = [ "--stdio" ];
        extensionToLanguage = {
          ".py"  = "python";
          ".pyi" = "python";
        };
      };

      ruff = {
        command = "ruff";
        args = [ "server" ];
        extensionToLanguage = {
          ".py"  = "python";
          ".pyi" = "python";
        };
        isLinter = true;
      };
    };
  });

  # Codex CLI ~/.codex/config.toml [lsp] block — same server set.
  # Activation merges idempotently — re-appends only if our managed
  # marker is missing.
  codexLspToml = pkgs.writeText "codex-lsp.toml" ''

    # --- managed by ~/nix-config/modules/home/lsp.nix (do not hand-edit) ---
    [lsp]
    enabled = true
    diagnosticsOnWrite = true
    diagnosticsOnEdit = false
    formatOnWrite = false

    # TS 7 / tsgo native LSP — 10-30x faster than tsserver.
    [lsp.servers.tsgo]
    command = "tsgo"
    args = ["--lsp", "--stdio"]
    extensions = [${jsExtsToml}]

    # oxc-based linter (Vite ecosystem).
    [lsp.servers.oxlint]
    command = "oxlint"
    args = ["--lsp"]
    extensions = [${jsAndVueExtsToml}]
    is_linter = true

    [lsp.servers.vue]
    command = "vue-language-server"
    args = ["--stdio"]
    extensions = [".vue"]

    [lsp.servers.astro]
    command = "astro-language-server"
    args = ["--stdio"]
    extensions = [".astro"]

    [lsp.servers.svelte]
    command = "svelteserver"
    args = ["--stdio"]
    extensions = [".svelte"]

    [lsp.servers.tailwindcss]
    command = "tailwindcss-language-server"
    args = ["--stdio"]
    extensions = [${tailwindExtsToml}]

    [lsp.servers.gopls]
    command = "gopls"
    extensions = [".go"]

    [lsp.servers.rust]
    command = "rust-analyzer"
    extensions = [".rs"]

    [lsp.servers.pyright]
    command = "basedpyright-langserver"
    args = ["--stdio"]
    extensions = [".py", ".pyi"]

    [lsp.servers.ruff]
    command = "ruff"
    args = ["server"]
    extensions = [".py", ".pyi"]
    is_linter = true

    [lsp.servers.lua]
    command = "lua-language-server"
    extensions = [".lua"]
    # --- end managed block ---
  '';
in
{
  home.packages = lspServers;

  # === Claude Code: declarative LSP config ===
  # Read-only Nix-managed file. Project-level `.lsp.json` at any repo
  # root still wins per Claude Code's config cascade.
  home.file.".claude/lsp.json".source = claudeLspJson;

  # === Codex CLI: idempotent [lsp] merge ===
  # Codex config.toml is fully user-managed (auth tokens, profiles,
  # marketplaces). We append our LSP block only if our managed marker
  # is absent — that way a user-authored `[lsp]` section coexists with
  # ours on next switch if they ever delete our block. Re-runs every
  # darwin-rebuild switch.
  home.activation.codexLspConfig = hm.dag.entryAfter [ "writeBoundary" ] ''
    target="${homeDir}/.codex/config.toml"
    [ -f "$target" ] || { echo "codex-lsp: $target missing, skipping" >&2; exit 0; }

    if ${pkgs.gnugrep}/bin/grep -qF 'managed by ~/nix-config/modules/home/lsp.nix' "$target"; then
      exit 0
    fi

    ${pkgs.coreutils}/bin/cat ${codexLspToml} >> "$target"
    echo "codex-lsp: appended managed [lsp] block to $target" >&2
  '';

  # === Claude Desktop / Codex App: ensure mcpServers key exists ===
  # We don't pre-bake per-workspace LSP→MCP bridges — that's per-project
  # and lives in templates/lsp-overrides/mcp-bridge.json. This activation
  # only guarantees the mcpServers object is present so the user can add
  # `lsp-<lang>` entries without losing surrounding preferences.
  # Darwin only.
  home.activation.claudeDesktopMcpScaffold =
    hm.dag.entryAfter [ "writeBoundary" ] ''
      target="${homeDir}/Library/Application Support/Claude/claude_desktop_config.json"
      [ -f "$target" ] || exit 0
      if ${pkgs.jq}/bin/jq -e '.mcpServers' "$target" >/dev/null 2>&1; then
        exit 0
      fi
      tmp=$(${pkgs.coreutils}/bin/mktemp)
      ${pkgs.jq}/bin/jq '. + { mcpServers: (.mcpServers // {}) }' \
        "$target" > "$tmp" && ${pkgs.coreutils}/bin/mv "$tmp" "$target"
      echo "claude-desktop: scaffolded empty mcpServers in $target" >&2
    '';
}
