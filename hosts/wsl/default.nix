{ inputs, currentSystemUser, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  martin.targets.wsl.enable = true;

  networking.hostName = "wsl";

  wsl = {
    enable = true;
    defaultUser = currentSystemUser;
  };
}
