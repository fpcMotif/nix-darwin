{ currentSystemUser, currentSystemUserHome, ... }:

{
  imports = [
    ./packages.nix
    ./prompt.nix
    ./skills.nix
  ];

  home = {
    username = currentSystemUser;
    homeDirectory = currentSystemUserHome;
    stateVersion = "24.05";
  };
}
