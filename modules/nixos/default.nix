{ lib, pkgs, currentSystemUser, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
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
    home = "/home/${currentSystemUser}";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  system.stateVersion = lib.mkDefault "25.05";
}
