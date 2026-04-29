{ inputs, currentSystemUser, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  networking.hostName = "wsl";

  wsl = {
    enable = true;
    defaultUser = currentSystemUser;
  };
}
