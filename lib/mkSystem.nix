{ inputs, overlays }:

{ system
, user
, hostModule
,
}:

let
  isDarwin = inputs.nixpkgs.lib.hasSuffix "darwin" system;
  systemFunc =
    if isDarwin then
      inputs.darwin.lib.darwinSystem
    else
      inputs.nixpkgs.lib.nixosSystem;
  homeManagerModule =
    inputs.home-manager.${if isDarwin then "darwinModules" else "nixosModules"}.home-manager;
  sharedArgs = {
    inherit inputs;
    currentSystemUser = user;
  };
in
systemFunc {
  inherit system;
  specialArgs = sharedArgs;

  modules = [
    {
      nixpkgs = {
        inherit overlays;
        config.allowUnfree = true;
      };
    }

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
