{ lib, ... }:

{
  # Homebrew is kept as an emergency, opt-in scaffold.
  martin.brew.homebrew.enable = false;

  imports = [
    ./brew-variants.nix
    ./defaults.nix
    ./fonts.nix
    ./hammerspoon.nix
    ./mouse-display.nix
    ./nix.nix
    ./rime.nix
    ./security.nix
    ./shell.nix
    ./skhd.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";
}
