# Lint and format checks for the flake. Wired through `flake.checks.<system>`
# in flake.nix; runs via `nix flake check` (locally and in CI).
#
# Each check is a runCommand derivation that fails the build if its tool
# reports findings. Top-level paths are listed explicitly so `references/`
# (third-party samples, never imported) and non-Nix dirs (`scripts/`,
# `skills/`) are excluded without source filtering.
{ inputs, self, system }:
let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  scanPaths = [ "flake.nix" "lib" "modules" "hosts" "pkgs" "tests" ];
  scanArgs = builtins.concatStringsSep " " scanPaths;
in
{
  fmt = pkgs.runCommand "check-fmt"
    { nativeBuildInputs = [ pkgs.nixpkgs-fmt ]; } ''
    cd ${self}
    nixpkgs-fmt --check ${scanArgs}
    touch $out
  '';

  statix = pkgs.runCommand "check-statix"
    { nativeBuildInputs = [ pkgs.statix ]; } ''
    cd ${self}
    for path in ${scanArgs}; do
      echo "==> statix check $path"
      statix check "$path"
    done
    touch $out
  '';

  deadnix = pkgs.runCommand "check-deadnix"
    { nativeBuildInputs = [ pkgs.deadnix ]; } ''
    cd ${self}
    deadnix --fail ${scanArgs}
    touch $out
  '';
}
