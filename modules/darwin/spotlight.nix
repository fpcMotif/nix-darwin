{ config, lib, currentSystemUser, currentSystemUserHome, ... }:

let
  cfg = config.martin.spotlight;
  markerText = "managed by nix-config martin.spotlight";
in
{
  options.martin.spotlight = {
    enable = lib.mkEnableOption "Spotlight churn controls for development trees";

    excludedPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${currentSystemUserHome}/.bun"
        "${currentSystemUserHome}/.cache"
        "${currentSystemUserHome}/.cargo"
        "${currentSystemUserHome}/.codex"
        "${currentSystemUserHome}/.rustup"
        "${currentSystemUserHome}/cleanmole-expo"
        "${currentSystemUserHome}/gosh-my-pi"
        "${currentSystemUserHome}/ghostty"
        "${currentSystemUserHome}/kwwk"
        "${currentSystemUserHome}/Mole"
        "${currentSystemUserHome}/nix-config"
        "${currentSystemUserHome}/pi"
        "${currentSystemUserHome}/pi-gui"
      ];
      description = ''
        Development/cache directories that should not feed Spotlight's content index.
        Code search is handled by rg, ast-grep, fff/codedb, and mgrep instead.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home-manager.users.${currentSystemUser}.programs.git.ignores = [
        ".metadata_never_index"
      ];
    })

    {
      martin.darwinBaseline.activationState.pathMarkers = [
        {
          name = "spotlightExclusions";
          enable = cfg.enable;
          stateFile = "${currentSystemUserHome}/Library/Application Support/nix-config/spotlight-exclusions";
          paths = cfg.excludedPaths;
          markerName = ".metadata_never_index";
          inherit markerText;
        }
      ];
    }
  ];
}
