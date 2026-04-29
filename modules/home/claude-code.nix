{ pkgs, ... }:

# Stable user-PATH entry that survives store-path changes across upgrades, so
# macOS TCC permissions and editor integrations don't re-prompt every
# `darwin-rebuild switch`. Cross-platform — harmless on Linux.
{
  home.file.".local/bin/claude".source = pkgs.claude-code + "/bin/claude";
}
