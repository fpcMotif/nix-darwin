{ currentSystemUser, currentSystemUserHome, ... }:

{
  imports = [
    ./packages.nix
    ./prompt.nix
    ./skills.nix
    ./claude-code.nix
    ./droid.nix
    ./opencode.nix
    ./zed.nix
  ];

  home = {
    username = currentSystemUser;
    homeDirectory = currentSystemUserHome;
    stateVersion = "24.05";
  };
}
