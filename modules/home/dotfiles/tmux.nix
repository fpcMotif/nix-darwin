{ config, lib, pkgs, ... }:

let
  cfg = config.martin.dotfiles;
  dotfilesLib = import ./lib.nix { inherit lib; };
  profileAsset = dotfilesLib.profileAsset ./. cfg.keymap.profile;
  tmuxConfig = builtins.replaceStrings
    [ "@zsh@" ]
    [ "${pkgs.zsh}/bin/zsh" ]
    (builtins.readFile (profileAsset "tmux/tmux.conf"));
in
{
  config = lib.mkIf cfg.tmux.enable {
    warnings = lib.optional cfg.tmux.enableTpm (
      "martin.dotfiles.tmux.enableTpm only writes TPM config; it does not fetch network plugins during activation."
    );

    home.activation.checkMartinDotfilesTmux = dotfilesLib.guardTargets [
      ".config/tmux/tmux.conf"
    ];

    home.packages = with pkgs; [
      tmux
      zsh
    ];

    xdg.configFile."tmux/tmux.conf".text =
      tmuxConfig
      + lib.optionalString cfg.tmux.enableTpm ''

        ${builtins.readFile ./assets/common/tmux/tpm.conf}
      '';
  };
}
