{ config, lib, pkgs, ... }:

{
  imports = [
    ../options.nix
  ];

  nixpkgs = {
    hostPlatform = lib.mkDefault "aarch64-darwin";
    config.allowUnfree = true;
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "martinfan" ];
  };

  programs.zsh.enable = true;
  security.pam.services.sudo_local.touchIdAuth = true;

  # Kept as a future hook only. Homebrew stays disabled unless a host opts in.
  homebrew = lib.mkIf config.martin.homebrew.enable {
    enable = true;
    onActivation.cleanup = "none";
  };

  environment.shells = [
    pkgs.zsh
  ];
}
