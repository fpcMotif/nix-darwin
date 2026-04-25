{
  description = "Martin's nix-darwin configuration";

  # ─────────────────────────────────────────────────────────────────────────
  # Architecture (see ARCHITECTURE.md for the full rationale & comparison):
  #
  #   Nix-darwin  → system layer  : macOS defaults, services, system apps
  #                                 (Dropbox, Google Drive, Raycast).
  #   home-manager → user layer   : per-user CLI binaries (bat/fd/rg/eza/…)
  #                                 used by the chezmoi-managed dotfiles.
  #   chezmoi      → config files : zsh rc.d/, starship.toml, ghostty,
  #                                 ~/.claude, ~/.pi (templated, mutable).
  #
  # Why this split: chezmoi's modular rc.d/ + templates are excellent and
  # rewriting them as Nix strings buys nothing. The actual breakage was that
  # the *binaries* the dotfiles reference (bat, fd, rg, eza, …) weren't
  # installed by Nix — they were drifting in from /opt/zerobrew. Pinning the
  # tools in home-manager closes that gap and gives us atomic rollback,
  # reproducibility, and one declarative source of versions, while keeping
  # chezmoi's lightweight workflow for the config text itself.
  #
  # Brew status: REMOVED. The previous nix-homebrew bridge declared a single
  # `windsurf@next` cask — Windsurf.app was never installed (likely killed by
  # the historical `cleanup = "zap"` incident, see ARCHITECTURE.md). We've
  # dropped the bridge entirely. To migrate any future Mac app, write a
  # custom derivation alongside dropbox/google-drive/raycast above.
  # ─────────────────────────────────────────────────────────────────────────

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Per-user package & dotfile management. We use home-manager strictly
    # for `home.packages` here — config files stay in chezmoi.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, darwin, home-manager, ... }:
  let
    system = "aarch64-darwin";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };

    # Custom Dropbox derivation - downloads latest from official source
    dropbox = pkgs.stdenv.mkDerivation rec {
      pname = "dropbox";
      version = "latest";

      src = pkgs.fetchurl {
        url = "https://www.dropbox.com/download?plat=mac&full=1";
        name = "Dropbox.dmg";
        sha256 = "sha256-i6tOrY1MZBcK018q1YlXIf3CagcI9zpGl6wJjYZ7ha4=";
      };

      nativeBuildInputs = [ pkgs.undmg ];
      sourceRoot = ".";
      phases = [ "unpackPhase" "installPhase" ];

      installPhase = ''
        mkdir -p $out/Applications
        cp -r "Dropbox.app" $out/Applications/
      '';

      meta = {
        description = "Dropbox client";
        homepage = "https://www.dropbox.com";
        platforms = [ "aarch64-darwin" "x86_64-darwin" ];
      };
    };

    # Custom Google Drive derivation
    google-drive = pkgs.stdenv.mkDerivation rec {
      pname = "google-drive";
      version = "latest";

      src = pkgs.fetchurl {
        url = "https://dl.google.com/drive-file-stream/GoogleDrive.dmg";
        sha256 = "sha256-zrFs+5BWqjSzvxrQFcR1NlGes8Mhp6OLdx6sjYFuZGY=";
      };

      # undmg will unpack the DMG and leave GoogleDrive.pkg in the source root
      nativeBuildInputs = [ pkgs.undmg ];
      sourceRoot = ".";
      phases = [ "unpackPhase" "installPhase" ];

      installPhase = ''
        set -euo pipefail

        mkdir -p "$out/Applications"

        # Expand the pkg so we can get at the arm64 app bundle
        /usr/sbin/pkgutil --expand-full "GoogleDrive.pkg" expanded

        # Copy the arm64 Google Drive.app from the expanded payload
        cp -R "expanded/GoogleDrive_arm64.pkg/Payload/Google Drive.app" "$out/Applications/"
      '';

      meta = {
        description = "Google Drive client";
        homepage = "https://www.google.com/drive/";
        platforms = [ "aarch64-darwin" "x86_64-darwin" ];
      };
    };

    # Custom Raycast derivation
    raycast = pkgs.stdenv.mkDerivation rec {
      pname = "raycast";
      version = "latest";

      src = pkgs.fetchurl {
        url = "https://api.raycast.app/v2/download";
        name = "Raycast.dmg";
        sha256 = "sha256-XNGUMjIAJmHOz8uwfCor3vcR9n2hftEo5TmWwZMcojQ=";
      };

      nativeBuildInputs = [ pkgs.undmg ];
      sourceRoot = ".";
      phases = [ "unpackPhase" "installPhase" ];

      installPhase = ''
        mkdir -p $out/Applications
        cp -r "Raycast.app" $out/Applications/
      '';

      meta = {
        description = "Raycast launcher";
        homepage = "https://www.raycast.com";
        platforms = [ "aarch64-darwin" "x86_64-darwin" ];
      };
    };
  in
  {
    darwinConfigurations."Martins-Mac-mini" = darwin.lib.darwinSystem {
      inherit system;
      modules = [
        # home-manager runs as a darwin module so `darwin-rebuild switch`
        # rebuilds the user profile atomically alongside the system.
        # useGlobalPkgs/useUserPackages keeps a single nixpkgs instance
        # (no duplicate store paths, faster eval, smaller closure).
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.martinfan = import ./home.nix;
          };
        }

        ({ pkgs, ... }: {
          nixpkgs.config.allowUnfree = true;

          # Declare the user so home-manager's common module can derive
          # `home.homeDirectory` correctly. nix-darwin won't try to *create*
          # the account — `martinfan` already exists in macOS Open Directory.
          users.users.martinfan.home = "/Users/martinfan";

          # System layer: GUI apps + things that genuinely need to be
          # system-wide. Per-user CLI tools (gemini-cli, codex, bat, fd, …)
          # live in home.nix instead — that's the canonical split.
          environment.systemPackages = [
            dropbox
            google-drive
            raycast
          ];

          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          system.stateVersion = 5;
          system.primaryUser = "martinfan";
          programs.zsh.enable = true;
        })
      ];
    };
  };
}
