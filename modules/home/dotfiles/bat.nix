{ config, lib, ... }:

let
  cfg = config.martin.dotfiles.bat;
  dotfilesLib = import ./lib.nix { inherit lib; };
  themeNames = [
    "Catppuccin Frappe"
    "Catppuccin Latte"
    "Catppuccin Macchiato"
    "Catppuccin Mocha"
  ];
in
{
  config = lib.mkIf cfg.enable {
    home.activation.checkMartinDotfilesBat = dotfilesLib.guardTargets (
      [ ".config/bat/config" ]
      ++ map (theme: ".config/bat/themes/${theme}.tmTheme") themeNames
    );

    programs.bat = {
      enable = true;
      config.theme = "Catppuccin Mocha";
      themes = lib.genAttrs themeNames (theme: {
        src = ./assets/common/bat/themes;
        file = "${theme}.tmTheme";
      });
    };
  };
}
