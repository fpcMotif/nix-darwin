{ lib, pkgs, ... }:

let
  guards = lib.concatMapStringsSep " " (p: "${p}") [
    ../claude/hooks/search-guard.sh
    ../claude/hooks/shell-guard.sh
  ];
in
{
  home.file = {
    ".gemini/config/hooks/agy-guard.sh" = { source = ./agy-guard.sh; executable = true; };
    ".gemini/config/hooks.json".source = pkgs.writeText "antigravity-hooks.json" (builtins.toJSON {
      shell-guards.PreToolUse = [
        {
          matcher = "run_command";
          hooks = [
            {
              type = "command";
              command = "~/.gemini/config/hooks/agy-guard.sh ${guards}";
              timeout = 10;
            }
          ];
        }
      ];
    });
  };
}
