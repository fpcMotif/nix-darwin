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

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agent-skills = {
      url = "github:Kyure-A/agent-skills-nix/master";
      inputs.home-manager.follows = "home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:fpcMotif/dotfiles";
      flake = false;
    };

    mattpocock-skills = {
      url = "github:mattpocock/skills/main";
      flake = false;
    };

    effect-ts-skills = {
      url = "github:Effect-TS/skills/main";
      flake = false;
    };

    superpowers = {
      url = "github:obra/superpowers/main";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systemUser = "martinfan";

      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];

      checkSystems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];

      hostDefinitions = {
        f = {
          system = "aarch64-darwin";
          target = "darwin";
          hostModule = ./hosts/darwin;
        };

        wsl = {
          system = "x86_64-linux";
          target = "nixos";
          hostModule = ./hosts/wsl;
        };

        x230 = {
          system = "x86_64-linux";
          target = "nixos";
          hostModule = ./hosts/x230;
        };

        vm-aarch64-utm = {
          system = "aarch64-linux";
          target = "nixos";
          hostModule = ./hosts/vm-aarch64-utm;
        };
      };

      overlays = [
        inputs.nur.overlays.default
        (import ./pkgs)
        inputs.claude-code.overlays.default
      ];

      mkSystem = import ./lib/mkSystem.nix {
        inherit inputs overlays;
      };

      mkConfiguredSystem = hostname: host:
        mkSystem {
          inherit hostname;
          user = systemUser;
          inherit (host) system hostModule;
        };

      hostsFor = target:
        builtins.mapAttrs mkConfiguredSystem
          (lib.filterAttrs (_: host: host.target == target) hostDefinitions);

      legacyPackagesFor = s:
        let
          pkgs = import nixpkgs {
            system = s;
            inherit overlays;
            config.allowUnfree = true;
          };
        in
        {
          crush = pkgs.nur.repos.charmbracelet.crush;
          martin = pkgs.martin;
        };
    in
    {
      darwinConfigurations = hostsFor "darwin";
      nixosConfigurations = hostsFor "nixos";

      legacyPackages = lib.genAttrs supportedSystems legacyPackagesFor;

      formatter = lib.genAttrs supportedSystems
        (s: nixpkgs.legacyPackages.${s}.nixpkgs-fmt);

      checks = lib.genAttrs checkSystems (s:
        import ./tests {
          inherit inputs self;
          system = s;
        }
      );
    };
}
