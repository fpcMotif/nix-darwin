{ config, lib, pkgs, ... }:

let
  hk = pkgs.martin.hk-bin;
  hookEvents = [ "commit-msg" "pre-commit" "pre-push" "prepare-commit-msg" ];
  hookCommand = event:
    ''test "''${HK:-1}" = "0" || ${lib.getExe hk} run ${event} --from-hook''
    + lib.optionalString (event == "pre-commit") " --staged";
in
{
  home.packages = [ hk ];

  programs.git.settings.hook = lib.listToAttrs (map
    (event: lib.nameValuePair "hk-${event}" { inherit event; command = hookCommand event; })
    hookEvents);

  xdg.configFile."hk/config.pkl" = lib.mkIf config.martin.development.docLock {
    text = ''
      amends "package://github.com/jdx/hk/releases/download/v${hk.version}/hk@${hk.version}#/Config.pkl"

      hooks {
        ["pre-commit"] {
          steps {
            ["doc-lock"] {
              check = "${lib.getExe pkgs.martin.doc-lock} staged"
            }
          }
        }
      }
    '';
  };
}
