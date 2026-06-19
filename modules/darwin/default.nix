{ ... }:

{
  # Homebrew is kept as an emergency, opt-in scaffold.
  martin.brew.homebrew.enable = false;

  imports = [
    ./auto-switch.nix
    ./baseline-activation.nix
    ./background-services.nix
    ./brew-variants.nix
    ./defaults.nix
    ./fonts.nix
    ./hammerspoon.nix
    ./health-check.nix
    ./linux-builder.nix
    ./mouse-display.nix
    ./nix.nix
    ./rime.nix
    ./security.nix
    ./shell.nix
    ./skhd.nix
    ./spotlight.nix
    ./zed.nix
  ];

}
