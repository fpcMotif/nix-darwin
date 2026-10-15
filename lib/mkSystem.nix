{ inputs, overlays }:

{ system
, user
, hostname
, hostModule
,
}:

let
  lib = inputs.nixpkgs.lib;
  isDarwin = lib.hasSuffix "darwin" system;
  systemFunc =
    if isDarwin then
      inputs.darwin.lib.darwinSystem
    else
      inputs.nixpkgs.lib.nixosSystem;
  homeManagerModule =
    inputs.home-manager.${if isDarwin then "darwinModules" else "nixosModules"}.home-manager;
  currentSystemUserHome =
    if isDarwin then "/Users/${user}" else "/home/${user}";
  # darwin-rebuild keys off localHostName when no #name is passed.
  # Keep the flake attribute name in flake.nix equal to hostname.
  hostNameModule =
    if isDarwin then {
      networking = {
        hostName = hostname;
        localHostName = hostname;
      };
    } else {
      networking.hostName = hostname;
    };
  sharedArgs = {
    inherit inputs currentSystemUserHome;
    currentSystemUser = user;
  };
in
systemFunc {
  inherit system;
  specialArgs = sharedArgs;

  modules = [
    {
      nixpkgs = {
        hostPlatform = lib.mkDefault system;
        inherit overlays;
        config.allowUnfree = true;
      };
    }

    hostNameModule

    (if isDarwin then ../modules/darwin else ../modules/nixos)

    homeManagerModule
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = sharedArgs;
        users.${user} = import ../modules/home;
      };
    }

    hostModule
  ];
}
