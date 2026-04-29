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
  currentSystemUserHome =
    if isDarwin then "/Users/${user}" else "/home/${user}";
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
