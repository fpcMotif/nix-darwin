{ pkgs, lib, config, ... }:

let
  cfg = {
    "$schema" = "https://opencode.ai/config.json";
    theme = "system";
    autoshare = false;
    autoupdate = false; # Nix manages updates; in-app updater would lose them.
  };
in
{
  # Keep a stable user-PATH symlink so macOS TCC grants survive store-path updates.
  home.file.".local/bin/opencode".source =
    pkgs.martin.opencode + "/bin/opencode";

  # Initial config — only written if absent, so opencode can mutate it.
  home.activation.opencodeConfigSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    cfgdir="${config.home.homeDirectory}/.config/opencode"
    cfgfile="$cfgdir/opencode.json"
    if [ ! -e "$cfgfile" ]; then
      run mkdir -p "$cfgdir"
      run install -m 0644 ${pkgs.writeText "opencode.json" (builtins.toJSON cfg)} "$cfgfile"
    fi
  '';
}
