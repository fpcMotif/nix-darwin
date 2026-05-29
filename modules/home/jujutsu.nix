{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "fpcmotif";
        email = "fpcmotif@gmail.com";
      };

      ui = {
        "default-command" = "log";

        # Render jj diffs as delta hunks, reusing the git delta config
        # (modules/home/git.nix). `diff-formatter = ":git"` makes jj emit
        # git-format diffs delta can parse; `pager = "delta"` pipes them
        # through it — so `jj diff`/`jj show`/`jj log -p` and interactive
        # `jj split -i`/`jj squash -i` all get syntax-highlighted hunks.
        #
        # `pager` is global, so `jj log` (the default command) also flows
        # through delta; delta passes non-diff content through untouched. To
        # scope delta to diffs only, replace these two keys with jj's
        # conditional config:
        #   [[--scope]]
        #   --when.commands = ["diff", "show"]
        #   [--scope.ui]
        #   pager = "delta"
        #   diff-formatter = ":git"
        pager = "delta";
        "diff-formatter" = ":git";
      };
    };
  };
}
