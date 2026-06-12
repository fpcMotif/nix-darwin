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

      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
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

      pkgsFor = s:
        import nixpkgs {
          system = s;
          inherit overlays;
          config.allowUnfree = true;
        };

      legacyPackagesFor = s:
        let
          pkgs = pkgsFor s;
        in
        {
          crush = pkgs.nur.repos.charmbracelet.crush;
          martin = pkgs.martin;
        };
    in
    {
      darwinConfigurations = hostsFor "darwin";
      nixosConfigurations = hostsFor "nixos";

      # The repo's own overlay (pkgs.martin.* and friends), reusable by other
      # flakes without re-importing ./pkgs by path.
      overlays.default = import ./pkgs;

      legacyPackages = lib.genAttrs supportedSystems legacyPackagesFor;

      # Reproducible OCI dev container, Linux-only by nature. Build it on the
      # Mac via martin.linuxBuilder (modules/darwin/linux-builder.nix) or on a
      # Linux machine/CI, then load with `docker load < result`.
      packages = lib.genAttrs linuxSystems (s: {
        dev-container = (pkgsFor s).callPackage ./pkgs/dev-container.nix { };
      });

      # Repo dev shell: `nix develop` (or direnv via the root .envrc) provides
      # the pinned maintainer toolchain — just, formatter, and the Nix linters
      # `just lint` runs.
      devShells = lib.genAttrs supportedSystems (s:
        let
          pkgs = pkgsFor s;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = [
              pkgs.just
              pkgs.nixpkgs-fmt
              pkgs.statix
              pkgs.deadnix
              pkgs.shellcheck
            ];
          };
        });

      # Seed for per-project pinned dev environments:
      #   nix flake init -t <this-flake>#dev-shell
      templates = {
        dev-shell = {
          path = ./templates/dev-shell;
          description = "Pinned per-project dev shell (flake devShell + direnv .envrc)";
        };
        default = self.templates.dev-shell;
      };

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
