{ inputs }:

let
  repoPackages = import ../pkgs;

  inputPackages = final: prev: {
    martin = prev.martin // {
      traits = final.callPackage ../pkgs/traits.nix { src = inputs.traits; };
      iets-classic = final.callPackage ../pkgs/iets { inherit (inputs) iets; };
      inherit (import inputs.charm-nur { pkgs = final; }) crush;
    };
  };
in
{
  all = [
    inputs.rust-overlay.overlays.default
    repoPackages
    inputPackages
    inputs.claude-code.overlays.default
  ];

  default = inputs.nixpkgs.lib.composeManyExtensions [ repoPackages inputPackages ];
}
