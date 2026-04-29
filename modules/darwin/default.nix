{ lib, ... }:

{
  imports = [
    ./brew-variants.nix
    ./nix.nix
    ./security.nix
    ./shell.nix
    ./system-defaults.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
}
