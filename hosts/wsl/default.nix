{ inputs, currentSystemUser, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  networking.hostName = "wsl";

  nix = {
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };

  wsl = {
    enable = true;
    defaultUser = currentSystemUser;

    # Practical defaults for a WSL-first Linux workflow.
    startMenuLaunchers = true;
    wslConf = {
      automount.root = "/mnt";
    };
  };
}
