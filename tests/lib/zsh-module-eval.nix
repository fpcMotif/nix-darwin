# Evaluate modules/home/zsh.nix standalone -- outside a full home-manager
# configuration -- so tests can read the module's generated text and toggle
# martin.shell.viMode without re-evaluating an entire host configuration.
#
# Only the attributes tests actually read are declared (and therefore
# merged/validated); everything else the module writes passes through
# freeform attrsets and is never looked at. The module system requires each
# declared subtree's parents to be declared too, hence the programs level.
# If the zsh module starts writing a namespace that breaks evaluation here,
# the fix is one more declared (or freeform-covered) level in this shim --
# failures are loud, never silently swallowed.
#
# Kept free of import-from-derivation on purpose: this evaluates on any
# platform, unlike full-host evaluations (see the agent-skills IFD caveat in
# tests/integration/configurations-eval-test.nix).
{ pkgs, lib }:
{ viMode ? null }:

(lib.evalModules {
  modules =
    [
      {
        options.xdg.configHome = lib.mkOption {
          type = lib.types.str;
          default = "/home/tester/.config";
        };

        options.home = lib.mkOption {
          type = lib.types.submodule {
            freeformType = lib.types.attrsOf lib.types.raw;
            options.username = lib.mkOption {
              type = lib.types.str;
              default = "tester";
            };
            options.homeDirectory = lib.mkOption {
              type = lib.types.str;
              default = "/home/tester";
            };
            options.sessionVariables = lib.mkOption {
              type = lib.types.attrsOf (lib.types.oneOf [
                lib.types.str
                lib.types.int
                lib.types.path
              ]);
              default = { };
            };
            options.sessionPath = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          };
        };

        options.programs = lib.mkOption {
          type = lib.types.submodule {
            freeformType = lib.types.attrsOf lib.types.raw;

            options.zsh = lib.mkOption {
              type = lib.types.submodule {
                freeformType = lib.types.attrsOf lib.types.raw;
                options.initContent = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                };
                options.plugins = lib.mkOption {
                  type = lib.types.listOf lib.types.anything;
                  default = [ ];
                };
                options.defaultKeymap = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
              };
            };
          };
        };

        config._module.args.pkgs = pkgs;
        config._module.freeformType = lib.types.attrsOf lib.types.raw;
      }
      ../../modules/home/zsh.nix
    ]
    ++ lib.optionals (viMode != null) [
      { martin.shell.viMode.enable = lib.mkForce viMode; }
    ];
}).config
