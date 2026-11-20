{ pkgs, iets, nix }:

let
  ietsBin = iets.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    # Upstream evaluates for x86_64-linux on every host, so on the Mac
    # `iets print-dev-env .` builds the Linux dev shell and fails.
    patches = (old.patches or [ ]) ++ [ ./host-system.patch ];
  });
in
iets.lib.mkClassic pkgs ietsBin nix
