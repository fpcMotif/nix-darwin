{ config, lib, pkgs, ... }:

let
  cfg = config.martin.dotfiles;
  dotfilesLib = import ./lib.nix { inherit lib; };
  profileAsset = dotfilesLib.profileAsset ./. cfg.keymap.profile;
in
{
  config = lib.mkIf cfg.kitty.enable {
    warnings = lib.optional cfg.kitty.allowRemoteControl (
      "martin.dotfiles.kitty.allowRemoteControl enables socket-only kitty remote control on /tmp/kitty_term."
    );

    home.activation.checkMartinDotfilesKitty = dotfilesLib.guardTargets [
      ".config/kitty/kitty.conf"
      ".config/kitty/keymap.py"
      ".config/kitty/window.py"
      ".config/kitty/testing.py"
      ".config/kitty/themes"
    ];

    home.packages = [ pkgs.kitty ];

    xdg.configFile = {
      "kitty/kitty.conf".text =
        builtins.readFile (profileAsset "kitty/kitty.conf")
        + lib.optionalString cfg.kitty.allowRemoteControl ''

          allow_remote_control socket-only
          listen_on unix:/tmp/kitty_term
          remote_control_password "" kitten
        '';
      "kitty/keymap.py".source = ./assets/common/kitty/keymap.py;
      "kitty/window.py".source = profileAsset "kitty/window.py";
      "kitty/testing.py".source = ./assets/common/kitty/testing.py;
      "kitty/themes".source = ./assets/common/kitty/themes;
    };
  };
}
