# Integration test: the shared Home Manager profile must stay portable.
#
# modules/home is imported by every host — the active Mac AND the staged
# Linux scaffolds (wsl, x230, vm-aarch64-utm). macOS-only filesystem paths
# (/Applications bundles, ~/Library trees) and macOS-only commands must be
# gated behind `pkgs.stdenv.isDarwin` so they never reach a Linux host's
# session environment, shell config, or activation scripts.
#
# Pure eval-level assertions (no builds): each surface below is the merged
# option value a Linux host would actually receive.
{ pkgs
, lib
, wslConfigurationInput
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

  # includeActivation: forcing home.activation bodies makes agent-skills
  # resolve its bundle via import-from-derivation, which only builds on the
  # configuration's own platform. The CI builder is x86_64-linux, so wsl/x230
  # get the activation surface and the aarch64 VM is checked on its pure
  # (string-option) surfaces only — the modules are shared, so wsl/x230
  # activation coverage extends to it.
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
          "${prefix} ${surface} leaks Darwin-only content into a Linux host: ${lib.concatStringsSep ", " offenders}. Gate it behind pkgs.stdenv.isDarwin in modules/home.")
      surfaces;
in
helpers.testSuite "home-linux-purity" (
  hostChecks "wsl" true wslConfigurationInput
  ++ hostChecks "x230" true x230ConfigurationInput
  ++ hostChecks "vm-aarch64-utm" false vmConfigurationInput
)
