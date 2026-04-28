{ lib, ... }:

{
  options.martin.targets = {
    wsl.enable = lib.mkEnableOption "the inactive NixOS-WSL scaffold";
    x230.enable = lib.mkEnableOption "the inactive ThinkPad X230 scaffold";
  };

  config.martin.targets = {
    wsl.enable = lib.mkDefault false;
    x230.enable = lib.mkDefault false;
  };
}
