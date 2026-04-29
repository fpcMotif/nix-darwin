{ lib, ... }:

{
  imports = [
    ./brew-variants.nix
    ./defaults.nix
    ./nix.nix
    ./security.nix
    ./shell.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
}
