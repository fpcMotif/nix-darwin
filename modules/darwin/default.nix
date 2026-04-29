{ lib, ... }:

{
  # Homebrew is kept as an emergency, opt-in scaffold.
  martin.brew.homebrew.enable = false;

  imports = [
    ./brew-variants.nix
    ./defaults.nix
    ./nix.nix
    ./security.nix
    ./shell.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
}
