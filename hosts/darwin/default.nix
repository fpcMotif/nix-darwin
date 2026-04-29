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

  home-manager.users.${currentSystemUser}.martin.prompt.starship = {
    enable = true;
    palette.enable = true;
    powerline.enable = true;

    segments = {
      rootIndicator.enable = true;
      path.enable = true;
      git.enable = true;
      status.enable = true;
      rPromptTime.enable = true;
    };
  };
}
