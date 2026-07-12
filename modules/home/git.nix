{ config, ... }:

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
        fomo = "!branch=$(git remote show -n origin | awk '/HEAD branch:/ {print $NF}'); if [ -z \"$branch\" ]; then echo \"Could not resolve origin HEAD\" >&2; exit 1; fi; git fetch origin \"$branch\" && git rebase \"origin/$branch\" --autostash";
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

      # Nix-built git resolves CA certs only via $NIX_SSL_CERT_FILE, which the
      # interactive shell exports but GUI apps (Conductor, etc.) launched from
      # Finder/launchd do not inherit -> "unable to get local issuer certificate
      # (20)" on https fetches. Pin the bundle in config so git finds it in every
      # context. /etc/ssl/certs/ca-certificates.crt is managed by nix-darwin.
      http.sslCAInfo = "/etc/ssl/certs/ca-certificates.crt";

      init.defaultBranch = "main";

      merge.conflictstyle = "zdiff3";

      # Auto-resolve version/hash churn in auto-updated pkgs/*.nix (mapped via
      # the repo's .gitattributes); see scripts/git-merge-pkgnix.sh.
      merge.pkgnix = {
        name = "newer-version-wins for auto-updated package pins";
        driver = "${config.home.homeDirectory}/nix-config/scripts/git-merge-pkgnix.sh %O %A %B %L %P";
      };

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
