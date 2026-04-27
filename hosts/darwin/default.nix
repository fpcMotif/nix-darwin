{ pkgs, ... }:

{
  users.users.martinfan.home = "/Users/martinfan";

  system = {
    primaryUser = "martinfan";
    stateVersion = 5;
  };

  environment.systemPackages = with pkgs.martin; [
    dropbox
    google-drive
    raycast
  ];
}
