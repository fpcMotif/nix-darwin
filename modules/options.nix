{ lib, ... }:

{
  options.martin = {
    homebrew.enable = lib.mkEnableOption "the inactive Homebrew scaffold";

    targets = {
      wsl.enable = lib.mkEnableOption "the inactive NixOS-WSL scaffold";
      x230.enable = lib.mkEnableOption "the inactive ThinkPad X230 scaffold";
    };
  };

  config.martin = {
    homebrew.enable = lib.mkDefault false;
    targets.wsl.enable = lib.mkDefault false;
    targets.x230.enable = lib.mkDefault false;
  };
}
