{ lib, pkgs, ... }:

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
}
