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
    ./skills.nix
  ];

  home = {
    username = currentSystemUser;
    inherit homeDirectory;

    # Pin the Home Manager schema we wrote against. Bump deliberately.
    stateVersion = "24.05";
  };
}
