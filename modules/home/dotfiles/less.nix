{ config, lib, pkgs, ... }:

let
  cfg = config.martin.dotfiles;
  dotfilesLib = import ./lib.nix { inherit lib; };
  profileAsset = dotfilesLib.profileAsset ./. cfg.keymap.profile;
in
{
  config = lib.mkIf cfg.less.enable {
    home.activation.checkMartinDotfilesLess = dotfilesLib.guardTargets [
      ".config/less/.lesskey"
    ];

    home.packages = [ pkgs.less ];

    home.sessionVariables = {
      LESSKEYIN = "${config.home.homeDirectory}/.config/less/.lesskey";
      LESSHISTFILE = "${config.home.homeDirectory}/.config/less/.lesshst";
    };

    xdg.configFile."less/.lesskey".source = profileAsset "less/.lesskey";
  };
}
