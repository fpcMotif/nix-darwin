{ lib, pkgs, ... }:

{
  home.activation.checkNixManagedGit = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -e "$HOME/.gitconfig" ] && ! [ -L "$HOME/.gitconfig" ]; then
      echo "ERROR: ~/.gitconfig is still unmanaged." >&2
      echo "Please archive/remove it so Home Manager can manage git settings." >&2
      exit 1
    fi

    if [ -e "$HOME/.config/git/config" ] && ! [ -L "$HOME/.config/git/config" ]; then
      echo "ERROR: ~/.config/git/config is still unmanaged." >&2
      echo "Please archive/remove it so Home Manager can manage git settings." >&2
      exit 1
    fi
  '';

  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      alias = {
        fomo = "!branch=$(git remote show -n origin | awk '/HEAD branch:/ {print $NF}'); if [ -z \"$branch\" ]; then echo \"Could not resolve origin HEAD\" >&2; exit 1; fi; git fetch origin \"$branch\" && git rebase \"origin/$branch\" --autostash";
        lg = "log --graph --oneline --decorate --all";
        nuke = "!git add --all && git stash && git stash clear";
      };

      branch.sort = "-committerdate";

      core = {
        editor = "nvim";
        fsmonitor = true;
        pager = "delta";
      };

      diff.colorMoved = "default";

      fetch = {
        prune = true;
        writeCommitGraph = true;
      };

      interactive.diffFilter = "${pkgs.delta} --color-only";
      init.defaultBranch = "main";
      merge.conflictstyle = "diff3";
      pull.rebase = true;
      rebase.updateRefs = true;
      rerere.enabled = true;

      delta = {
        side-by-side = true;
        navigate = true;
        light = false;
      };
    };
  };
}
