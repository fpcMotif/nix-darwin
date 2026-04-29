{ config, lib, pkgs, ... }:

let
  cfg = config.martin.dotfiles;
  dotfilesLib = import ./lib.nix { inherit lib; };
  profileAsset = dotfilesLib.profileAsset ./. cfg.keymap.profile;
in
{
  config = lib.mkIf cfg.zsh.enable {
    home.activation.checkMartinDotfilesZsh = dotfilesLib.guardTargets [
      ".zshenv"
      ".config/zsh/.zshenv"
      ".config/zsh/.zshrc"
      ".config/zsh/function.zsh"
      ".config/zsh/keymap.zsh"
      ".config/zsh/fzf.zsh"
      ".config/zsh/tabtab/pnpm.zsh"
    ];

    home.packages = with pkgs; [
      zsh
      fzf
      zsh-autosuggestions
      zsh-completions
      zsh-history-substring-search
      zsh-syntax-highlighting
    ];

    home.file.".zshenv".text = ''
      export ZDOTDIR="$HOME/.config/zsh"
      [ -r "$ZDOTDIR/.zshenv" ] && source "$ZDOTDIR/.zshenv"
    '';

    xdg.configFile = {
      "zsh/.zshenv".source = ./assets/common/zsh/.zshenv;
      "zsh/.zshrc".source = ./assets/common/zsh/.zshrc;
      "zsh/function.zsh".source = ./assets/common/zsh/function.zsh;
      "zsh/keymap.zsh".source = profileAsset "zsh/keymap.zsh";
      "zsh/fzf.zsh".source = profileAsset "zsh/fzf.zsh";
      "zsh/tabtab/pnpm.zsh".source = ./assets/common/zsh/tabtab/pnpm.zsh;
    };

    xdg.dataFile = {
      "zsh/zsh-autosuggestions".source = "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions";
      "zsh/zsh-completions".source = "${pkgs.zsh-completions}/share/zsh/site-functions";
      "zsh/zsh-history-substring-search".source = "${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search";
      "zsh/zsh-syntax-highlighting".source = "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting";
      "zsh/fzf".source = "${pkgs.fzf}/share/fzf";
    };
  };
}
