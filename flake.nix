{
  description = "Martin's cross-platform Nix config: active nix-darwin Mac with Linux/WSL scaffolds";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "git+https://github.com/nix-community/NixOS-WSL.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills = {
      url = "git+https://github.com/Kyure-A/agent-skills-nix.git?ref=master";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "git+ssh://git@github.com/fpcMotif/dotfiles.git?ref=main";
      flake = false;
    };

    mattpocock-skills = {
      url = "git+https://github.com/mattpocock/skills.git?ref=main";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      overlays = [
        (import ./pkgs)
      ];

      mkSystem = import ./lib/mkSystem.nix {
        inherit inputs overlays;
      };
    in
    {
      darwinConfigurations."Martins-Mac-mini" = mkSystem {
        system = "aarch64-darwin";
        user = "martinfan";
        hostModule = ./hosts/darwin;
      };

      nixosConfigurations.wsl = mkSystem {
        system = "x86_64-linux";
        user = "martinfan";
        hostModule = ./hosts/wsl;
      };

      nixosConfigurations.x230 = mkSystem {
        system = "x86_64-linux";
        user = "martinfan";
        hostModule = ./hosts/x230;
      };

      formatter = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-linux" ]
        (s: nixpkgs.legacyPackages.${s}.nixpkgs-fmt);
    };
}
