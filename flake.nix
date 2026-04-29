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

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills = {
      url = "git+https://github.com/Kyure-A/agent-skills-nix.git?ref=master";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:fpcMotif/dotfiles";
      flake = false;
    };

    mattpocock-skills = {
      url = "git+https://github.com/mattpocock/skills.git?ref=main";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      overlays = [
        (import ./pkgs)
        inputs.claude-code.overlays.default
      ];

      mkSystem = import ./lib/mkSystem.nix {
        inherit inputs overlays;
      };

      legacyPackagesFor = s:
        let
          pkgs = import nixpkgs {
            system = s;
            inherit overlays;
            config.allowUnfree = true;
          };
        in
        {
          inherit (pkgs) crush;
          martin = pkgs.martin;
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

      nixosConfigurations.vm-aarch64-utm = mkSystem {
        system = "aarch64-linux";
        user = "martinfan";
        hostModule = ./hosts/vm-aarch64-utm;
      };

      legacyPackages = nixpkgs.lib.genAttrs supportedSystems legacyPackagesFor;

      formatter = nixpkgs.lib.genAttrs supportedSystems
        (s: nixpkgs.legacyPackages.${s}.nixpkgs-fmt);

      checks = nixpkgs.lib.genAttrs supportedSystems (s:
        import ./tests {
          inherit inputs self;
          system = s;
        }
      );
    };
}
