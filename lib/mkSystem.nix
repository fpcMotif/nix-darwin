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
  # `hostname` is the single source of truth for the OS host name (and, on
  # darwin, localHostName — what `darwin-rebuild --flake` keys off of when no
  # explicit #name is passed). The flake attribute name is a separate literal
  # in flake.nix that must be kept equal to `hostname` by convention; nothing
  # structural prevents divergence, so the mksystem-test
  # `*-host-name-matches-flake-attr` assertions check that equality per host.
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
