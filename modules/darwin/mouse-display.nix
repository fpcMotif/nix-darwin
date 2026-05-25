{ config, inputs, lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

let
  cfg = config.martin.mouseDisplay;
  hmDag = inputs.home-manager.lib.hm.dag;
  bettermouseSeed = "${currentSystemUserHome}/Library/Application Support/BetterMouse/bm_cfg.plist";
  appLogDir = "${currentSystemUserHome}/Library/Logs/nix-managed-apps";
  profileSource =
    if cfg.bettermouse.profile == null
    then ""
    else toString cfg.bettermouse.profile;
in
{
  options.martin.mouseDisplay = {
    enable = lib.mkEnableOption "BetterMouse + BetterDisplay GUI apps with declarative seed config";

    bettermouse.profile = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = null;
      example = "${currentSystemUserHome}/MyRime-main/better_mouse_setting_bm_cfg_4958.plist";
      description = ''
        Optional binary plist exported from BetterMouse (Preferences → Export). When set, the file
        is copied to ~/Library/Application Support/BetterMouse/ on activation as a one-shot seed.
        BetterMouse owns the file after first launch — touch the source to re-seed.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.martin.bettermouse
      pkgs.betterdisplay
    ];

    home-manager.users.${currentSystemUser} = {
      home.activation.bettermouseSeed = hmDag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p "${appLogDir}"

        if [ -n "${profileSource}" ]; then
          seed_dir="${currentSystemUserHome}/Library/Application Support/BetterMouse"
          stamp="$seed_dir/.nix-seed-source"
          src="${profileSource}"

          run mkdir -p "$seed_dir"

          if [ ! -f "$src" ]; then
            echo "[bettermouse] profile source not found: $src" >&2
          elif [ ! -f "$stamp" ] || [ "$(cat "$stamp" 2>/dev/null)" != "$src" ]; then
            echo "[bettermouse] seeding profile from $src"
            run install -m 0644 "$src" "${bettermouseSeed}"
            printf %s "$src" > "$stamp"
          fi
        fi
      '';

      launchd.agents = {
        betterdisplay = {
          enable = true;
          config = {
            ProgramArguments = [
              "/usr/bin/open"
              "-g"
              "${pkgs.betterdisplay}/Applications/BetterDisplay.app"
            ];
            ProcessType = "Interactive";
            RunAtLoad = true;
            StandardErrorPath = "${appLogDir}/betterdisplay.stderr.log";
            StandardOutPath = "${appLogDir}/betterdisplay.stdout.log";
          };
        };

        bettermouse = {
          enable = true;
          config = {
            ProgramArguments = [
              "/usr/bin/open"
              "-g"
              "${pkgs.martin.bettermouse}/Applications/BetterMouse.app"
            ] ++ lib.optionals (cfg.bettermouse.profile != null) [
              "--args"
              bettermouseSeed
            ];
            ProcessType = "Interactive";
            RunAtLoad = true;
            StandardErrorPath = "${appLogDir}/bettermouse.stderr.log";
            StandardOutPath = "${appLogDir}/bettermouse.stdout.log";
          };
        };
      };
    };
  };
}
