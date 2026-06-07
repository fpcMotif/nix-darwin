{ lib, pkgs, ... }:

let
  toolSrc = lib.cleanSource ../../tools/skill-router;
  bun = pkgs.martin.bun-canary-bin or pkgs.bun;
  skillRouter = pkgs.writeShellScriptBin "skill-router" ''
    exec ${bun}/bin/bun ${toolSrc}/src/cli.ts "$@"
  '';
in
{
  home.packages = [ skillRouter ];
}
