{ lib, pkgs, ... }:

# User profile only: iets is v0.1, so nix.package, the daemon, sudo
# darwin-rebuild and the Linux hosts keep the plain nix.
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.packages = [ pkgs.martin.iets-classic ];
  };
}
