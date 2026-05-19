{ config, lib, ... }:

# Stable user-PATH binary symlinks at ~/.local/bin/<name> backed by Nix
# store paths. The store path itself rotates on every input bump or
# package rebuild; ~/.local/bin/<name> stays put — so macOS TCC
# permissions and editor integrations stay anchored across
# `darwin-rebuild switch`.
#
# Declare per-binary alongside the tool that owns it:
#
#   martin.stablePath.binaries.claude = pkgs.claude-code;
#
# This module also handles first-activation takeover at the target path,
# replacing the per-path `remove_legacy_path` entries that previously
# mirrored every binary in cleanup.nix.

let
  cfg = config.martin.stablePath;

  binaryModule = lib.types.submodule ({ name, ... }: {
    options = {
      package = lib.mkOption {
        type = lib.types.package;
        description = "Derivation providing the binary.";
      };
      binary = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Binary name inside `<package>/bin/`. Defaults to the attr key.";
      };
    };
  });
in
{
  options.martin.stablePath = {
    binaries = lib.mkOption {
      type = lib.types.attrsOf (lib.types.coercedTo
        lib.types.package
        (pkg: { package = pkg; })
        binaryModule);
      default = { };
      example = lib.literalExpression ''
        {
          claude = pkgs.claude-code;
          droid = pkgs.martin.droid;
        }
      '';
      description = ''
        User-PATH binary symlinks at ~/.local/bin/<name>. Stable across
        store-path churn so macOS TCC and editor integrations don't
        re-prompt every `darwin-rebuild switch`.

        Pass a derivation directly when `<package>/bin/<name>` matches the
        attr key (the common case); use the explicit form
        `{ package = pkgs.x; binary = "y"; }` when the binary name differs.
      '';
    };
  };

  config = lib.mkIf (cfg.binaries != { }) {
    home.file = lib.mapAttrs'
      (name: spec: lib.nameValuePair
        ".local/bin/${name}"
        { source = "${spec.package}/bin/${spec.binary}"; })
      cfg.binaries;

    # First-activation takeover: home.file refuses to overwrite a non-symlink
    # at the target path. Sweep any pre-Nix file (chezmoi-rendered, manually
    # installed, etc.) before home-manager checks the link targets.
    home.activation.stablePathTakeover = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      for p in ${lib.escapeShellArgs (lib.mapAttrsToList (n: _: ".local/bin/${n}") cfg.binaries)}; do
        if [ -e "$HOME/$p" ] && [ ! -L "$HOME/$p" ]; then
          rm -f -- "$HOME/$p"
        fi
      done
    '';
  };
}
