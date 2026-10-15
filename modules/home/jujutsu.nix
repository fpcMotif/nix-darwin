{ pkgs, ... }:
{
  home.packages = [ pkgs.martin.jj-pr ];

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "fpcmotif";
        email = "fpcmotif@gmail.com";
      };

      aliases.pr = [ "util" "exec" "--" "jj-pr" ];

      ui = {
        "default-command" = "log";

        # Emit git-format diffs so delta highlights hunks in jj diff and jj show.
        # delta passes non-diff output like jj log through untouched.
        pager = "delta";
        "diff-formatter" = ":git";
      };
    };
  };
}
