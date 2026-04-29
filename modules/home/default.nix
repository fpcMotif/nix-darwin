{ pkgs, currentSystemUser, ... }:

let
  homeDirectory =
    if pkgs.stdenv.isDarwin then
      "/Users/${currentSystemUser}"
    else
      "/home/${currentSystemUser}";
in
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
    inherit homeDirectory;
    stateVersion = "24.05";
  };
}
