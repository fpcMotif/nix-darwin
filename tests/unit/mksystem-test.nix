{ inputs, system, pkgs, lib, self, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };

  mkSystem = import ../../lib/mkSystem.nix;
  partial = mkSystem { inherit inputs; overlays = [ ]; };

  isDarwin = lib.hasSuffix "darwin" system;
  user = "martinfan";

  darwinConfig = self.darwinConfigurations."f".config;
  x230Config = self.nixosConfigurations.x230.config;
  vmConfig = self.nixosConfigurations.vm-aarch64-utm.config;

  homeConfig =
    if isDarwin then darwinConfig.home-manager.users.${user}
    else x230Config.home-manager.users.${user};

  expectedHomeDirectory = if isDarwin then "/Users/${user}" else "/home/${user}";

  hasPackage = name: packages:
    lib.any (pkg: lib.getName pkg == name) packages;

  commonChecks = [
    (helpers.assertTest "mksystem-is-function"
      (builtins.isFunction mkSystem)
      "lib/mkSystem.nix should evaluate to a function")

    (helpers.assertTest "mksystem-partial-application-returns-function"
      (builtins.isFunction partial)
      "mkSystem { inputs; overlays; } should return a function awaiting host args")

    (helpers.assertTest "home-manager-user-is-current-user"
      (homeConfig.home.username == user)
      "Home Manager should receive currentSystemUser from mkSystem")

    (helpers.assertTest "home-manager-home-directory-matches-platform"
      (homeConfig.home.homeDirectory == expectedHomeDirectory)
      "Home directory should be platform-specific for ${user}")

    (helpers.assertTest "common-home-packages-include-git"
      (hasPackage "git" homeConfig.home.packages)
      "common Home Manager packages should include git")

    (helpers.assertTest "common-home-packages-include-go"
      (hasPackage "go" homeConfig.home.packages)
      "common Home Manager packages should include the Go toolchain")

    (helpers.assertTest "common-home-packages-include-rust-toolchain"
      (hasPackage "rust-minimal" homeConfig.home.packages)
      "common Home Manager packages should include martin.rust-toolchain (cargo, rustc, clippy, rustfmt, rust-analyzer)")


    (helpers.assertTest "agent-skills-enabled"
      (homeConfig.programs.agent-skills.enable == true)
      "agent-skills Home Manager module should be enabled")
  ];

  darwinChecks = lib.optionals isDarwin [
    (helpers.assertTest "darwin-primary-user"
      (darwinConfig.system.primaryUser == user)
      "Darwin system.primaryUser should match the configured user")

    (helpers.assertTest "darwin-user-home"
      (darwinConfig.users.users.${user}.home == "/Users/${user}")
      "Darwin user home should match the active macOS account")

    (helpers.assertTest "darwin-host-platform"
      (darwinConfig.nixpkgs.hostPlatform.system == "aarch64-darwin")
      "Active Darwin host should target Apple Silicon")

    (helpers.assertTest "darwin-host-name-matches-flake-attr"
      (darwinConfig.networking.localHostName == "f"
        && darwinConfig.networking.hostName == "f")
      "Darwin localHostName/hostName must equal the flake attribute name (f) so `darwin-rebuild --flake` resolves without an explicit #name")

    (helpers.assertTest "darwin-nix-flakes-enabled"
      (builtins.elem "flakes" darwinConfig.nix.settings.experimental-features)
      "Darwin nix settings should enable flakes")

    (helpers.assertTest "darwin-nix-substituters-exclude-garnix"
      (!(builtins.elem "https://cache.garnix.io" darwinConfig.nix.settings.substituters))
      "Darwin Nix substituters should exclude unavailable Garnix")

    (helpers.assertTest "darwin-pi-extension-auto-update"
      (
        !homeConfig.martin.piOmp.enable
        || (
          let agent = homeConfig.launchd.agents.pi-extension-update.config;
          in agent.StartCalendarInterval.Hour == 6
          && agent.StartCalendarInterval.Minute == 15
          && agent.RunAtLoad == false
        )
      )
      "When enabled, Darwin should update mutable Pi extensions daily after the Nix auto-switch")

    (helpers.assertTest "darwin-system-packages-include-duti"
      (hasPackage "duti" darwinConfig.environment.systemPackages)
      "Darwin host should include the duti system package")

    (helpers.assertTest "darwin-home-packages-include-swiftlint"
      (hasPackage "swiftlint" homeConfig.home.packages)
      "Darwin Home Manager packages should include Swift/iOS lint tooling")
  ];

  linuxChecks = lib.optionals (!isDarwin) [
    (helpers.assertTest "x230-host-name-matches-flake-attr"
      (x230Config.networking.hostName == "x230")
      "x230 networking.hostName must equal its flake attribute name (driven by mkSystem's hostname arg, not the host module)")

    (helpers.assertTest "x230-grub-enabled"
      (x230Config.boot.loader.grub.enable == true)
      "x230 configuration should keep GRUB enabled")

    (helpers.assertTest "vm-aarch64-utm-host-name-matches-flake-attr"
      (vmConfig.networking.hostName == "vm-aarch64-utm")
      "vm-aarch64-utm networking.hostName must equal its flake attribute name (driven by mkSystem's hostname arg, not the host module)")
    (helpers.assertTest "linux-host-platforms-match-host-definitions"
      (
        x230Config.nixpkgs.hostPlatform.system == "x86_64-linux"
        && vmConfig.nixpkgs.hostPlatform.system == "aarch64-linux"
      )
      "NixOS host platforms should come from the flake host definitions")
    (helpers.assertTest "linux-user-home"
      (x230Config.users.users.${user}.home == "/home/${user}")
      "NixOS users should use Linux home directories")
  ];
in
helpers.testSuite "mksystem" (commonChecks ++ darwinChecks ++ linuxChecks)
