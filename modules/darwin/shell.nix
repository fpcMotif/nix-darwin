{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableGlobalCompInit = false;
    enableBashCompletion = false;
    promptInit = "";
  };

  environment.shells = [
    pkgs.zsh
  ];
}
