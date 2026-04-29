{ inputs, currentSystemUser, ... }:

{
  imports = [
    inputs.nixos-wsl.nixosModules.wsl
  ];

  networking.hostName = "wsl";

  # Borrowed from the Mitchell Hashimoto WSL reference: retain derivation
  # outputs for faster local rebuild iteration and use the conventional /mnt
  # Windows drive mount root.
  nix.extraOptions = ''
    keep-outputs = true
    keep-derivations = true
  '';

  wsl = {
    enable = true;
    defaultUser = currentSystemUser;
    startMenuLaunchers = true;
    wslConf.automount.root = "/mnt";
  };
}
