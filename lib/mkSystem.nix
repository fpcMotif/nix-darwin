{ inputs, overlays }:

{
  name,
  system,
  user,
  platform,
  hostModule,
}:

let
  isDarwin = platform == "darwin";
  systemFunc =
    if isDarwin then
      inputs.darwin.lib.darwinSystem
    else
      inputs.nixpkgs.lib.nixosSystem;
  homeManagerModule =
    if isDarwin then
      inputs.home-manager.darwinModules.home-manager
    else
      inputs.home-manager.nixosModules.home-manager;
  sharedArgs = {
    inherit inputs;
    currentSystem = system;
    currentSystemName = name;
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
