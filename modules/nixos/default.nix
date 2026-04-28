{ lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
  };

  # 🛡️ Sentinel: Restrict sudo execution to wheel group for defense in depth
  security.sudo.execWheelOnly = true;

  programs.zsh.enable = true;
  time.timeZone = lib.mkDefault "Australia/Perth";

  users.users.${currentSystemUser} = {
    isNormalUser = true;
    home = currentSystemUserHome;
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
