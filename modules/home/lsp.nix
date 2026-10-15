{ pkgs, lib, config, ... }:

# vue-language-server is skipped: with no aarch64-darwin cache hit, it
# compiled on every bump.

let
  inherit (lib) hm;

  homeDir = config.home.homeDirectory;
  codexLsp = import ../shared/codex-lsp.nix { inherit lib pkgs; };

  # ~/.claude/lsp.json for Claude Code's LSP tool. The `typescript-lsp` plugin
  # adds a second TS server; disable it to keep tsc alone. Unsupported keys:
  # fileTypes, rootMarkers, restartOnCrash, maxRestarts.
  claudeLspJson = pkgs.writeText "claude-lsp.json" (builtins.toJSON codexLsp.adapters.claude);

in
{
  home.packages = codexLsp.packages;

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
