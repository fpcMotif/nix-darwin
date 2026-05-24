{ ... }:

{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
      hyperlinks = true;
      syntax-theme = "ansi";
      light = false;
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    signing.format = null;

    ignores = [
      ".DS_Store"
      ".AppleDouble"
      ".LSOverride"
      "._*"
      "*.swp"
      "*.swo"
      "*~"
      ".idea/"
      ".vscode/settings.json"
      "**/.claude/settings.local.json"
      ".env"
      ".env.local"
      ".env.*.local"
      "node_modules/"
    ];

    settings = {
      user = {
        name = "fpcmotif";
        email = "fpcmotif@gmail.com";
      };

      alias = {
        fomo =
          "!branch=$(git remote show -n origin | awk '/HEAD branch:/ {print $NF}'); "
          + "if [ -z \"$branch\" ]; then echo \"Could not resolve origin HEAD\" >&2; exit 1; fi; "
          + "git fetch origin \"$branch\" && git rebase \"origin/$branch\" --autostash";
        lg = "log --graph --oneline --decorate --all";
        nuke = "!git add --all && git stash && git stash clear";
      };

      branch.sort = "-committerdate";
      tag.sort = "-version:refname";

      core = {
        editor = "nvim";
        fsmonitor = true;
        autocrlf = "input";
        ignorecase = false;
      };

      column.ui = "auto";

      color.ui = true;

      "color \"status\"" = {
        added = "green bold";
        changed = "yellow bold";
        untracked = "red bold";
      };

      "color \"branch\"" = {
        current = "green bold";
        local = "yellow";
        remote = "cyan";
      };

      "delta \"decorations\"" = {
        file-style = "bold yellow ul";
        file-decoration-style = "none";
        hunk-header-decoration-style = "cyan box ul";
      };

      diff = {
        algorithm = "histogram";
        colorMoved = "default";
        renames = "copies";
      };

      fetch = {
        prune = true;
        pruneTags = true;
        writeCommitGraph = true;
      };

      init.defaultBranch = "main";

      merge.conflictstyle = "zdiff3";

      pull.rebase = true;

      push = {
        default = "current";
        autoSetupRemote = true;
        followTags = true;
      };

      rebase = {
        autoStash = true;
        autoSquash = true;
        updateRefs = true;
      };

      rerere.enabled = true;

      "url \"git@github.com:\"".insteadOf = "gh:";
    };
  };
}
