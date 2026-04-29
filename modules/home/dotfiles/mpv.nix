{ config, lib, pkgs, ... }:

let
  cfg = config.martin.dotfiles;
  dotfilesLib = import ./lib.nix { inherit lib; };
  profileAsset = dotfilesLib.profileAsset ./. cfg.keymap.profile;
in
{
  config = lib.mkIf cfg.mpv.enable {
    warnings = [
      "martin.dotfiles.mpv enables the reference mpv IPC socket at /tmp/mpv.sock."
    ];

    home.activation.checkMartinDotfilesMpv = dotfilesLib.guardTargets [
      ".config/mpv/mpv.conf"
      ".config/mpv/input.conf"
      ".config/mpv/scripts"
      ".config/mpv/script-opts"
      ".config/mpv/shaders"
    ];

    home.packages = [ pkgs.mpv ];

    xdg.configFile = {
      "mpv/mpv.conf".source = ./assets/common/mpv/mpv.conf;
      "mpv/input.conf".source = profileAsset "mpv/input.conf";
      "mpv/scripts".source = ./assets/common/mpv/scripts;
      "mpv/script-opts".source = ./assets/common/mpv/script-opts;
      "mpv/shaders".source = ./assets/common/mpv/shaders;
    };
  };
}
