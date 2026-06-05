{ lib, pkgs, ... }:

let
  toolSrc = lib.cleanSource ../../tools/skill-router;
  bun = pkgs.martin.bun-canary-bin or pkgs.bun;
  skillRouter = pkgs.writeShellScriptBin "skill-router" ''
    exec ${bun}/bin/bun run ${toolSrc}/src/cli.ts "$@"
  '';
in
{
  home.packages = [ skillRouter ];

  home.file.".config/skill-router/config.json".source = "${toolSrc}/config.default.json";
}
