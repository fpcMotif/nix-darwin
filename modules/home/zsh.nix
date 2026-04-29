{ lib, ... }:

{
  home.activation.checkNixManagedZsh = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -e "$HOME/.zshrc" ] && ! [ -L "$HOME/.zshrc" ]; then
      echo "ERROR: ~/.zshrc is still unmanaged." >&2
      echo "Please archive/remove it so Home Manager can manage zsh settings." >&2
      exit 1
    fi
  '';

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim +Man!";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
    ];
    fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
    changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      c = "clear";
      code = "nvim";
      grep = "grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn --exclude-dir=.idea --exclude-dir=.tox";
      ks = "tmux kill-server";
      pbc = "pbcopy";
      pbp = "pbpaste";
      pn = "pnpm";
      oc = "opencode";
      scratch = "nvim -c \"setlocal buftype=nofile\"";
      vimdiff = "nvim -d";
      wr = "wrangler";
      lc = "localcode";
    };

    initContent = ''
      # Multi-dot cd: `cd ...` -> `cd ../..`, `cd ....` -> `cd ../../..`.
      cd() {
        if [[ $# -eq 1 && "$1" =~ '^\.\.\.+$' ]]; then
          local dots="$1"
          local dot_count=''${#dots}
          local target=""
          local i=1

          while (( i < dot_count )); do
            target+="../"
            i=$((i + 1))
          done

          builtin cd "$target"
          return
        fi

        builtin cd "$@"
      }

      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      if [ -f "$HOME/.zshrc.local" ]; then
        . "$HOME/.zshrc.local"
      fi
    '';
  };
}
