{ pkgs, currentSystemUser, ... }:

{
  users.users.${currentSystemUser}.home = "/Users/${currentSystemUser}";

  system = {
    primaryUser = currentSystemUser;
    stateVersion = 5;
  };

  environment.systemPackages = with pkgs.martin; [
    dropbox
    google-drive
    raycast
  ];
}
