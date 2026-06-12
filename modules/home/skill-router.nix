{ lib, pkgs, ... }:

let
  toolSrc = lib.cleanSource ../../tools/skill-router;
  # bun-canary-bin is an aarch64-darwin prebuilt (meta.platforms); Linux hosts
  # get stock bun. `or` was the wrong gate: the overlay attribute exists on
  # every platform — it just refuses to evaluate off-darwin, which broke the
  # wsl/x230 toplevels.
  bun = if pkgs.stdenv.isDarwin then pkgs.martin.bun-canary-bin else pkgs.bun;
  skillRouter = pkgs.writeShellScriptBin "skill-router" ''
    exec ${bun}/bin/bun ${toolSrc}/src/cli.ts "$@"
  '';
in
{
  home.packages = [ skillRouter ];
}
