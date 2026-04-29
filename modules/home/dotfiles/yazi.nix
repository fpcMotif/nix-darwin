{ config, lib, pkgs, ... }:

let
  cfg = config.martin.dotfiles;
  dotfilesLib = import ./lib.nix { inherit lib; };
  profileAsset = dotfilesLib.profileAsset ./. cfg.keymap.profile;
in
{
  config = lib.mkIf cfg.yazi.enable {
    warnings = [
      "martin.dotfiles.yazi links package.toml plugin pins but does not fetch external yazi plugins during activation."
    ];

    home.activation.checkMartinDotfilesYazi = dotfilesLib.guardTargets [
      ".config/yazi/yazi.toml"
      ".config/yazi/init.lua"
      ".config/yazi/theme.toml"
      ".config/yazi/package.toml"
      ".config/yazi/keymap.toml"
      ".config/yazi/plugins/folder-rules.yazi"
    ];

    home.packages = with pkgs; [
      yazi
      mediainfo
      socat
      opencc
    ];

    xdg.configFile = {
      "yazi/yazi.toml".source = ./assets/common/yazi/yazi.toml;
      "yazi/init.lua".source = ./assets/common/yazi/init.lua;
      "yazi/theme.toml".source = ./assets/common/yazi/theme.toml;
      "yazi/package.toml".source = ./assets/common/yazi/package.toml;
      "yazi/keymap.toml".source = profileAsset "yazi/keymap.toml";
      "yazi/plugins/folder-rules.yazi".source = ./assets/common/yazi/plugins/folder-rules.yazi;
    };
  };
}
