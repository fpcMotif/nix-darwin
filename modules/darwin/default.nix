{ lib, ... }:

{
  imports = [
    ../options.nix
    ./brew-variants.nix
    ./nix.nix
    ./security.nix
    ./shell.nix
  ];

  nixpkgs = {
    hostPlatform = lib.mkDefault "aarch64-darwin";
    config.allowUnfree = true;
  };
}
