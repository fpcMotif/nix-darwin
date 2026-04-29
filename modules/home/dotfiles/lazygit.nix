{ config, lib, pkgs, ... }:

let
  cfg = config.martin.dotfiles;
  dotfilesLib = import ./lib.nix { inherit lib; };
  profileAsset = dotfilesLib.profileAsset ./. cfg.keymap.profile;
in
{
  config = lib.mkIf cfg.lazygit.enable {
    home.activation.checkMartinDotfilesLazygit = dotfilesLib.guardTargets [
      ".config/lazygit/config.yml"
    ];

    home.packages = [ pkgs.difftastic ];

    xdg.configFile."lazygit/config.yml".source = profileAsset "lazygit/config.yml";
  };
}
