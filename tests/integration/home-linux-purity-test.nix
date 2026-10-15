{ pkgs
, lib
, x230ConfigurationInput
, vmConfigurationInput
, ...
}:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };

  user = "martinfan";

  # Substrings that identify Darwin-only paths or tools. Checked against
  # generated config text, so Nix-comment mentions in module sources don't
  # count — only what lands in the Linux closure does.
  macOnlyPatterns = [
    "/Applications/"
    "Library/Application Support"
    "Library/pnpm"
    "darwin-rebuild"
    "pbcopy"
    "pbpaste"
    "ipconfig getifaddr"
    "xcrun"
    "orbstack"
  ];

  offendersIn = text:
    builtins.filter (pat: lib.hasInfix pat text) macOnlyPatterns;

  # Forcing home.activation triggers agent-skills IFD on the host platform, so
  # x86_64-linux CI checks activation on x230 and string surfaces on the VM.
  hostChecks = prefix: includeActivation: configuration:
    let
      home = configuration.config.home-manager.users.${user};

      surfaces = {
        session-variables = lib.concatStringsSep "\n"
          (lib.mapAttrsToList (n: v: "${n}=${toString v}") home.home.sessionVariables);
        session-path = lib.concatStringsSep "\n" home.home.sessionPath;
        zsh-aliases = lib.concatStringsSep "\n"
          (lib.mapAttrsToList (n: v: "${n}=${toString v}") home.programs.zsh.shellAliases);
        zsh-env-extra = home.programs.zsh.envExtra;
        zsh-profile-extra = home.programs.zsh.profileExtra;
        zsh-init-content = home.programs.zsh.initContent;
      } // lib.optionalAttrs includeActivation {
        activation-scripts = lib.concatStringsSep "\n"
          (lib.mapAttrsToList (_: v: v.data) home.home.activation);
      };
    in
    lib.mapAttrsToList
      (surface: text:
        let offenders = offendersIn text;
        in helpers.assertTest "${prefix}-no-darwin-leak-${surface}"
          (offenders == [ ])
          "${prefix} ${surface} leaks Darwin-only content into a Linux host: ${lib.concatStringsSep ", " offenders}. Gate it behind pkgs.stdenv.hostPlatform.isDarwin in modules/home.")
      surfaces;
in
helpers.testSuite "home-linux-purity" (
  hostChecks "x230" true x230ConfigurationInput
  ++ hostChecks "vm-aarch64-utm" false vmConfigurationInput
)
