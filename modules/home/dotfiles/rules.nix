{ config, lib, ... }:

let
  cfg = config.martin.dotfiles.rules;
  dotfilesLib = import ./lib.nix { inherit lib; };
in
{
  config = lib.mkIf cfg.enable {
    home.activation.checkMartinDotfilesRules = dotfilesLib.guardTargets [
      ".config/rules"
    ];

    xdg.configFile."rules".source = ./assets/common/rules;
  };
}
