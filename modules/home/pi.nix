{ lib, pkgs, ... }:

{
  home.file.".pi/agent/extensions/glow.ts".source = pkgs.substituteAll {
    src = ./pi/glow.ts;
    glow = lib.getExe pkgs.glow;
  };
}
