{ pkgs, currentSystemUser, ... }:

{
  users.users.${currentSystemUser}.home = "/Users/${currentSystemUser}";

  system = {
    primaryUser = currentSystemUser;
    stateVersion = 5;
  };

  home-manager.users.${currentSystemUser}.martin.dotfiles = {
    keymap.profile = "vim";
    bat.enable = true;
    less.enable = true;
    lazygit.enable = true;
    rules.enable = true;
  };

  environment.systemPackages = with pkgs.martin; [
    dropbox
    google-drive
    raycast
  ];
}
