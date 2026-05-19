{ pkgs, lib, config, ... }:

# opencode CLI + Electron desktop. Both are Nix-installed; stable user-PATH
# symlinks come from martin.stablePath (see modules/home/stable-path.nix).
# Config lives at `~/.config/opencode/opencode.json` — managed declaratively
# here, but kept mutable so opencode itself can write transient runtime state
# (auth tokens, cached models) without fighting Nix.

let
  cfg = {
    "$schema" = "https://opencode.ai/config.json";
    theme = "system";
    autoshare = false;
    autoupdate = false; # Nix manages updates; in-app updater would lose them.
  };
in
{
  martin.stablePath.binaries = {
    opencode = pkgs.martin.opencode;
  } // lib.optionalAttrs pkgs.stdenv.isDarwin {
    opencode-electron = pkgs.martin.opencode-electron;
  };

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
