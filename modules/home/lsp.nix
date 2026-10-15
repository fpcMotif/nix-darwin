{ pkgs, lib, config, ... }:

let
  inherit (lib) hm;

  homeDir = config.home.homeDirectory;
  codexLsp = import ../shared/codex-lsp.nix { inherit lib pkgs; };

  # Disable the typescript-lsp plugin so tsc stays the sole TypeScript server.
  # Claude Code rejects fileTypes, rootMarkers, restartOnCrash, and maxRestarts.
  claudeLspJson = pkgs.writeText "claude-lsp.json" (builtins.toJSON codexLsp.adapters.claude);

in
{
  home.packages = codexLsp.packages;

  # Project-level .lsp.json at a repo root still overrides this file.
  home.file.".claude/lsp.json".source = claudeLspJson;

  # Seed only the top-level mcpServers key; bridges stay per-project in
  # templates/lsp-overrides/mcp-bridge.json.
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
