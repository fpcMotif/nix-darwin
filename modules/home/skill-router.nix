{ lib, pkgs, ... }:

let
  toolSrc = lib.cleanSource ../../tools/skill-router;
  # bun-canary-bin is aarch64-darwin only, and evaluating its overlay attribute
  # on Linux fails the NixOS toplevels even behind `or`.
  bun = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.martin.bun-canary-bin else pkgs.bun;
  skillRouter = pkgs.writeShellScriptBin "skill-router" ''
    exec ${bun}/bin/bun ${toolSrc}/src/cli.ts "$@"
  '';
in
{
  home.packages = [ skillRouter ];
}
