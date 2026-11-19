{ pkgs
, lib
, evalScope
, darwinConfigurationInput ? null
, darwinDojjoConfigurationInput ? null
, x230ConfigurationInput ? null
, vmConfigurationInput ? null
, ...
}:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };
  guideCatalog = import ../../modules/home/agent-instructions/guides.nix { inherit lib pkgs; };
  guideTargets = guideCatalog.targets;

  user = "martinfan";

  darwinConfiguration = if evalScope == "darwin" then darwinConfigurationInput else null;
  darwinConfig = if darwinConfiguration != null then darwinConfiguration.config else null;
  darwinSystem = if darwinConfiguration != null then darwinConfiguration.system else null;
  darwinHome = if darwinConfig != null then darwinConfig.home-manager.users.${user} else null;
  x230Configuration = if evalScope == "nixos" then x230ConfigurationInput else null;
  vmConfiguration = if evalScope == "nixos" then vmConfigurationInput else null;
  x230Config = if x230Configuration != null then x230Configuration.config else null;
  vmConfig = if vmConfiguration != null then vmConfiguration.config else null;
  x230Home = if x230Config != null then x230Config.home-manager.users.${user} else null;
  vmHome = if vmConfig != null then vmConfig.home-manager.users.${user} else null;

  evalsOk = drv:
    let r = builtins.tryEval (toString drv.drvPath);
    in r.success && r.value != "";

  # agent-skills resolves bundlePath via import-from-derivation, so foreign
  # toplevels abort with a platform mismatch and are checked on their native runner.
  toplevelEvaluatesOnNative = name: system: config:
    helpers.assertTest "nixos-${name}-evaluates"
      (system != pkgs.system || evalsOk config.system.build.toplevel)
      "nixosConfigurations.${name}.toplevel should evaluate (checked on its native builder)";

  hasPackage = name: packages:
    lib.any (pkg: lib.getName pkg == name) packages;

  # The real host with the experimental backend selected (tests/default.nix).
  # Only the default host is built by `just switch`.
  darwinDojjo = if evalScope == "darwin" then darwinDojjoConfigurationInput else null;
  darwinDojjoHome = darwinDojjo.config.home-manager.users.${user};

  ctx = {
    inherit lib helpers guideCatalog guideTargets user
      darwinConfig darwinSystem darwinHome
      x230Config vmConfig x230Home vmHome
      evalsOk toplevelEvaluatesOnNative hasPackage darwinDojjo darwinDojjoHome;
  };
  part = file: import file ctx;

  agentSurfaceChecks = part ./configurations-eval/agent-surface.nix;
  workspaceBackendChecks = part ./configurations-eval/workspace-backend.nix;
  homeChecks = part ./configurations-eval/home.nix;

  darwinChecks = part ./configurations-eval/darwin.nix
    ++ workspaceBackendChecks ++ agentSurfaceChecks
    ++ (homeChecks "darwin" darwinHome "/Users/${user}");

  nixosChecks = part ./configurations-eval/nixos.nix
    ++ (homeChecks "x230" x230Home "/home/${user}")
    ++ (homeChecks "vm-aarch64-utm" vmHome "/home/${user}");

  selectedChecks = if evalScope == "darwin" then darwinChecks else nixosChecks;
in
helpers.testSuite "configurations-eval" selectedChecks
