{ lib, pkgs, currentSystemUser, currentSystemUserHome, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
    substituters = [
      "https://cache.nixos.org"
      "https://claude-code.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
    ];
  };

  # 🛡️ Sentinel: Restrict sudo execution to wheel group for defense in depth
  security.sudo.execWheelOnly = true;

  # Keep CLI tools predictable across NixOS hosts and WSL.
  environment = {
    localBinInPath = true;
    pathsToLink = [ "/share/zsh" ];
    systemPackages = with pkgs; [
      curl
      git
      vim
    ];
  };

  programs = {
    zsh.enable = true;
    # Helpful for unpatched Linux binaries in dev/agent workflows.
    nix-ld.enable = true;
  };
  time.timeZone = lib.mkDefault "Australia/Perth";

  users.users.${currentSystemUser} = {
    isNormalUser = true;
    home = currentSystemUserHome;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  system.stateVersion = lib.mkDefault "25.05";
}
