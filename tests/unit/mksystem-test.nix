# Unit tests for lib/mkSystem.nix and the current host contract.
#
# mkSystem is a curried factory:
#   ({ inputs, overlays }) -> ({ system, user, hostname, hostModule }) -> systemConfig
#
# These tests evaluate the first-party configurations far enough to prove the
# current user, Home Manager profile, and host modules are wired through the
# factory. They do not build whole systems.
{ inputs, system, pkgs, lib, self, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };

  mkSystem = import ../../lib/mkSystem.nix;
  partial = mkSystem { inherit inputs; overlays = [ ]; };

  isDarwin = lib.hasSuffix "darwin" system;
  user = "martinfan";

  darwinConfig = self.darwinConfigurations."f".config;
  wslConfig = self.nixosConfigurations.wsl.config;
  x230Config = self.nixosConfigurations.x230.config;
  vmConfig = self.nixosConfigurations.vm-aarch64-utm.config;

  homeConfig =
    if isDarwin then darwinConfig.home-manager.users.${user}
    else wslConfig.home-manager.users.${user};

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

    (helpers.assertTest "agent-skills-enabled"
      (homeConfig.programs.agent-skills.enable == true)
      "agent-skills Home Manager module should be enabled")

    (helpers.assertTest "grill-with-docs-skill-enabled"
      (builtins.hasAttr "grill-with-docs" homeConfig.programs.agent-skills.skills.explicit)
      "grill-with-docs should stay exposed as an explicit transformed Matt Pocock skill")

    (helpers.assertTest "grill-me-skill-disabled"
      (
        !(builtins.elem "grill-me" homeConfig.programs.agent-skills.skills.enable)
        && !(builtins.hasAttr "grill-me" homeConfig.programs.agent-skills.skills.explicit)
      )
      "grill-me should stay disabled in the Matt Pocock skill allowlist")

    (helpers.assertTest "pi-skill-target-configured"
      (homeConfig.programs.agent-skills.targets.pi.dest == ".pi/agent/skills")
      "Oh My Pi skill target should be configured explicitly")
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

    (helpers.assertTest "darwin-system-packages-include-raycast"
      (hasPackage "raycast" darwinConfig.environment.systemPackages)
      "Darwin host should include the Raycast system package")
  ];

  linuxChecks = lib.optionals (!isDarwin) [
    (helpers.assertTest "wsl-host-name-matches-flake-attr"
      (wslConfig.networking.hostName == "wsl")
      "wsl networking.hostName must equal its flake attribute name (driven by mkSystem's hostname arg, not the host module)")

    (helpers.assertTest "wsl-default-user"
      (wslConfig.wsl.defaultUser == user)
      "WSL default user should come from currentSystemUser")

    (helpers.assertTest "x230-host-name-matches-flake-attr"
      (x230Config.networking.hostName == "x230")
      "x230 networking.hostName must equal its flake attribute name (driven by mkSystem's hostname arg, not the host module)")

    (helpers.assertTest "x230-grub-enabled"
      (x230Config.boot.loader.grub.enable == true)
      "x230 configuration should keep GRUB enabled")

    (helpers.assertTest "vm-aarch64-utm-host-name-matches-flake-attr"
      (vmConfig.networking.hostName == "vm-aarch64-utm")
      "vm-aarch64-utm networking.hostName must equal its flake attribute name (driven by mkSystem's hostname arg, not the host module)")

    (helpers.assertTest "linux-user-home"
      (x230Config.users.users.${user}.home == "/home/${user}")
      "NixOS users should use Linux home directories")
  ];
in
helpers.testSuite "mksystem" (commonChecks ++ darwinChecks ++ linuxChecks)
