{ lib, pkgs, currentSystemUser, ... }:

{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "root" "@wheel" ];
  };

  # Keep CLI tools predictable across hosts and shell paths.
  environment = {
    pathsToLink = [ "/share/zsh" ];
    systemPackages = with pkgs; [
      curl
      git
      vim
    ];
  };

  programs = {
    zsh.enable = true;
    # Helpful for unpatched Linux binaries in dev workflows.
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
