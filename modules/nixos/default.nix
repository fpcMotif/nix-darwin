{ lib, pkgs, currentSystemUser, ... }:

{
  imports = [
    ../options.nix
  ];

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
  };

  programs.zsh.enable = true;
  time.timeZone = lib.mkDefault "Australia/Perth";

  users.users.${currentSystemUser} = {
    isNormalUser = true;
    home = "/home/${currentSystemUser}";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  environment.systemPackages = with pkgs; [
    curl
    git
    vim
  ];

  system.stateVersion = lib.mkDefault "25.05";
}
