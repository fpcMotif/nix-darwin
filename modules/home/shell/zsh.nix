{ config, lib, pkgs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  viMode = config.martin.shell.viMode;
  search = config.martin.shell.search;

  gitPlaneOn = search.enable && search.gitObjects.enable;

  shared = import ./shared.nix { inherit lib isDarwin; };
  inherit (shared) terminfoDirs;
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf (config.martin.shell.interactive == "zsh") {
    home.packages = lib.optionals gitPlaneOn [
      pkgs.fzf-git-sh
    ];

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      completionInit = ''
        fpath=($HOME/.zsh/completions $fpath)
        autoload -Uz compinit && compinit -C
      '';
      autosuggestion.enable = false;
      syntaxHighlighting.enable = false;
      historySubstringSearch.enable = false;

      defaultKeymap = if viMode.enable then "viins" else "emacs";

      history = {
        path = "${config.xdg.configHome}/zsh/.history";
        size = 100000;
        save = 100000;
        ignoreAllDups = true;
        ignoreSpace = true;
        share = true;
      };

      sessionVariables = {
        WORDCHARS = "*?_-.[]~=&;!#$%^(){}<>";
      };

      shellAliases = shared.aliases // {
        reload = "source ~/.zshrc";
        ".." = "cd ..";
        "..." = "cd ../..";
        "...." = "cd ../../..";
        pymobiledevice3 = "source ~/.venv/bin/activate && python -m pymobiledevice3";
      };

      profileExtra = lib.optionalString isDarwin ''
        source ~/.orbstack/shell/init.zsh 2>/dev/null || :
      '';

      envExtra = ''
        typeset -U PATH path

        export TERMINFO="$HOME/.terminfo"
        typeset -aU _terminfo_dirs
        _terminfo_dirs=(
          ${lib.concatStringsSep "\n          " terminfoDirs}
          ''${(s/:/)TERMINFO_DIRS}
        )
        _terminfo_dirs=(''${_terminfo_dirs:#})
        (( ''${#_terminfo_dirs[@]} > 0 )) && export TERMINFO_DIRS="''${(j/:/)_terminfo_dirs}"
        unset _terminfo_dirs
      '';

      initContent = ''
        setopt AUTO_CD AUTO_MENU COMPLETE_IN_WORD NO_BEEP PROMPT_CR
        setopt HIST_VERIFY INTERACTIVE_COMMENTS HIST_FCNTL_LOCK HIST_FIND_NO_DUPS
        unsetopt NOMATCH AUTO_REMOVE_SLASH
        KEYTIMEOUT=1

        # Minimal native prompt: independent of Starship
        PROMPT='%F{cyan}%1~%f %# '

        # Proven native widgets
        autoload -Uz edit-command-line
        zle -N edit-command-line
        autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search

        for km in viins vicmd emacs; do
          bindkey -M "$km" '^[[A' up-line-or-beginning-search 2>/dev/null || :
          bindkey -M "$km" '^[OA' up-line-or-beginning-search 2>/dev/null || :
          bindkey -M "$km" '^P' up-line-or-beginning-search 2>/dev/null || :
          bindkey -M "$km" '^[[B' down-line-or-beginning-search 2>/dev/null || :
          bindkey -M "$km" '^[OB' down-line-or-beginning-search 2>/dev/null || :
          bindkey -M "$km" '^N' down-line-or-beginning-search 2>/dev/null || :
          bindkey -M "$km" '^[[3~' delete-char 2>/dev/null || :
          bindkey -M "$km" '^[[H' beginning-of-line 2>/dev/null || :
          bindkey -M "$km" '^[OH' beginning-of-line 2>/dev/null || :
          bindkey -M "$km" '^[[1~' beginning-of-line 2>/dev/null || :
          bindkey -M "$km" '^[[F' end-of-line 2>/dev/null || :
          bindkey -M "$km" '^[OF' end-of-line 2>/dev/null || :
          bindkey -M "$km" '^[[4~' end-of-line 2>/dev/null || :
          bindkey -M "$km" '^[[5~' beginning-of-buffer-or-history 2>/dev/null || :
          bindkey -M "$km" '^[[6~' end-of-buffer-or-history 2>/dev/null || :
          bindkey -M "$km" '^[[Z' reverse-menu-complete 2>/dev/null || :
          bindkey -M "$km" '^[[1;5D' backward-word 2>/dev/null || :
          bindkey -M "$km" '^[[1;3D' backward-word 2>/dev/null || :
          bindkey -M "$km" '^[^[[D' backward-word 2>/dev/null || :
          bindkey -M "$km" '^[[1;5C' forward-word 2>/dev/null || :
          bindkey -M "$km" '^[[1;3C' forward-word 2>/dev/null || :
          bindkey -M "$km" '^[^[[C' forward-word 2>/dev/null || :
          bindkey -M "$km" '^[[3;5~' kill-word 2>/dev/null || :
          bindkey -M "$km" '^[[3;3~' kill-word 2>/dev/null || :
          bindkey -M "$km" '^[^?' backward-kill-word 2>/dev/null || :
        done

        ${lib.optionalString viMode.enable ''
          # Native Zsh vi mode bindings
          bindkey -M vicmd 'vv' edit-command-line
          bindkey -M viins '^X^E' edit-command-line

          # Emacs reflexes in viins
          bindkey -M viins '^A' beginning-of-line
          bindkey -M viins '^E' end-of-line
          bindkey -M viins '^K' kill-line
          bindkey -M viins '^U' kill-whole-line
          bindkey -M viins '^W' backward-kill-word
        ''}

        ${lib.optionalString gitPlaneOn ''
          if [[ -r "${pkgs.fzf-git-sh}/share/fzf-git-sh/fzf-git.sh" ]]; then
            source "${pkgs.fzf-git-sh}/share/fzf-git-sh/fzf-git.sh"
            for km in viins vicmd emacs; do
              for k in b t r h s l e w; do
                bindkey -rM "$km" "${search.prefix}$k" 2>/dev/null || :
              done
            done
          fi
        ''}

        ${lib.optionalString (search.enable && (config.programs.fzf.enable or false)) ''
          martin-content-search-widget() {
            local query sel
            query="''${LBUFFER##*[[:space:]]}"
            if [[ -z $query ]]; then
              zle -M 'search plane: type a search term first, then press the chord again'
              return
            fi
            sel=$(fif "$query")
            zle -I
            [[ -n "$sel" ]] && LBUFFER+="$sel"
            zle reset-prompt
          }

          martin-process-kill-widget() {
            fkill
            zle -I
            zle reset-prompt
          }

          zle -N martin-content-search-widget
          zle -N martin-process-kill-widget

          for km in viins vicmd emacs; do
            ${lib.optionalString (search.keys.contentSearch != null) ''
              bindkey -M "$km" '${search.prefix}${search.keys.contentSearch}' martin-content-search-widget 2>/dev/null || :
            ''}
            ${lib.optionalString (search.keys.processKill != null) ''
              bindkey -M "$km" '${search.prefix}${search.keys.processKill}' martin-process-kill-widget 2>/dev/null || :
            ''}
            bindkey -rM "$km" '${search.prefix}' 2>/dev/null || :
          done
        ''}

        ${lib.optionalString (search.enable && (config.programs.zoxide.enable or false)) ''
          martin-dir-jump-widget() {
            local dir
            dir=$(command zoxide query -i)
            zle -I
            [[ -n "$dir" ]] && builtin cd "$dir"
            zle reset-prompt
          }

          zle -N martin-dir-jump-widget

          for km in viins vicmd emacs; do
            ${lib.optionalString (search.keys.dirJump != null) ''
              bindkey -M "$km" '${search.prefix}${search.keys.dirJump}' martin-dir-jump-widget 2>/dev/null || :
            ''}
            bindkey -rM "$km" '${search.prefix}' 2>/dev/null || :
          done
        ''}

        # Helper functions
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

        grep() { rg "$@" }

        du() {
          local -a args
          local a
          for a in "$@"; do
            if [[ "$a" == -[a-zA-Z]* ]]; then
              a="''${a//h/}"
              if [[ "$a" == *s* ]]; then
                a="''${a//s/}"
                args+=(-d 0)
              fi
              [[ "$a" == "-" ]] && continue
            fi
            args+=("$a")
          done
          command dust "''${args[@]}"
        }

        fif() {
          (( $# )) || return
          rg --files-with-matches --no-messages -- "$1" | \
            FIF_QUERY="$1" fzf \
              --prompt='󰈞 ' \
              --preview 'rg --ignore-case --pretty --context 10 -- "$FIF_QUERY" {}'
        }

        fkill() {
          local pid
          pid=$(ps -ef | sed 1d | fzf --prompt='󰆙 ' -m | awk '{print $2}')
          [[ -n "$pid" ]] && echo "$pid" | xargs -r kill "-''${1:-9}"
        }

        dev-info() {
          local -a out
          (( $+commands[git] )) && command git rev-parse --is-inside-work-tree >/dev/null 2>&1 && out+=("git:$(command git branch --show-current 2>/dev/null)")
          (( $+commands[jj] )) && command jj root >/dev/null 2>&1 && out+=("jj:$(command jj log -r @ -n 1 --no-graph -T 'change_id.shortest(6)' 2>/dev/null)")
          (( $+commands[node] )) && out+=("node:$(command node -v 2>/dev/null)")
          (( $+commands[bun] )) && out+=("bun:$(command bun -v 2>/dev/null)")
          (( $+commands[python3] )) && out+=("py:$(command python3 -V 2>/dev/null | cut -d' ' -f2)")
          (( $+commands[rustc] )) && out+=("rust:$(command rustc -V 2>/dev/null | cut -d' ' -f2)")
          (( $+commands[go] )) && out+=("go:$(command go version 2>/dev/null | cut -d' ' -f3)")
          print -P "%F{cyan}''${(j: %F{white}|%F{cyan} :)out}%f"
        }

        _ghostty_key() {
          if ! (( $+commands[skhd] )); then
            print -u2 "ghostty: skhd is not on PATH; run sync or use Ghostty's native keybinds"
            return 127
          fi
          command skhd -k "$1"
        }

        ghostty-split() {
          local action="''${1:-right}"
          local chord
          case "$action" in
            right|r|east|e) chord="cmd - d" ;;
            down|d|south|s) chord="cmd + shift - d" ;;
            zoom|z) chord="cmd + shift - f" ;;
            equal|eq|0) chord="cmd + shift - 0" ;;
            *)
              print -u2 "usage: ghostty-split {right|down|zoom|equal}"
              return 2
              ;;
          esac
          _ghostty_key "$chord"
        }

        ghostty-pane() {
          local action="''${1:-left}"
          local chord
          case "$action" in
            left|h|west|w) chord="cmd + alt - left" ;;
            right|l|east|e) chord="cmd + alt - right" ;;
            up|k|north|n) chord="cmd + alt - up" ;;
            down|j|south|s) chord="cmd + alt - down" ;;
            *)
              print -u2 "usage: ghostty-pane {left|right|up|down}"
              return 2
              ;;
          esac
          _ghostty_key "$chord"
        }

        ab() {
          if ! curl -s "http://localhost:9222/json/version" > /dev/null 2>&1; then
            ~/.local/bin/canary-debug > /dev/null 2>&1
          fi
          agent-browser "$@"
        }

        [[ -f "$HOME/.config/zsh/.secret" ]] && source "$HOME/.config/zsh/.secret"
        [[ -r $HOME/.zshrc.local ]] && source $HOME/.zshrc.local
      '';
    };
  };
}
