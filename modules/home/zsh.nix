{ config, lib, pkgs, ... }:

let
  inherit (pkgs.stdenv) isDarwin;

  # pnpm's platform-native global dir: ~/Library on macOS, XDG data on Linux.
  pnpmHome = if isDarwin then "$HOME/Library/pnpm" else "$HOME/.local/share/pnpm";

  # Terminal terminfo lookup chain. The /Applications entries are macOS app
  # bundles and must not leak into Linux environments.
  terminfoDirs = [
    "$HOME/.terminfo"
  ] ++ lib.optionals isDarwin [
    "/Applications/Ghostty.app/Contents/Resources/terminfo"
    "/Applications/kitty.app/Contents/Resources/kitty/terminfo"
    "/Applications/kitty.app/Contents/Resources/terminfo"
  ] ++ [
    "/usr/share/terminfo"
  ];
in
{
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    MANPAGER = "nvim +Man!";
    LANG = "en_US.UTF-8";
    LC_ALL = "en_US.UTF-8";

    BAT_THEME = "Catppuccin Macchiato";
    EZA_CONFIG_DIR = "$HOME/.config/eza";
    RANGER_LOAD_DEFAULT_RC = "FALSE";
    PNPM_HOME = pnpmHome;
    LESSKEYIN = "$HOME/.config/less/.lesskey";
    LESSHISTFILE = "$HOME/.config/less/.lesshst";
    POWERLINE_NERD_FONTS = "1";

    HOMEBREW_NO_ANALYTICS = "1";

    CDPATH = ".:$HOME:$HOME/Developer:$HOME/Downloads:$HOME/Documents";

    AGENT_BROWSER_CDP_URL = "http://localhost:9222";
    BUN_INSTALL = "$HOME/.bun";

    CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    CLAUDE_CODE_NO_FLICKER = "1";
    # Baseline effort floor for any `claude` launched OUTSIDE the ai-cli.nix
    # wrappers (IDE, raw ~/.local/bin/claude, inherited shells): xhigh, never
    # max. The `claude`/`cc` wrappers `unset` this so they run full ultracode
    # (xhigh + dynamic-workflow orchestration) instead. See modules/home/ai-cli.nix.
    CLAUDE_CODE_EFFORT_LEVEL = "xhigh";

    OBSIDIAN_VAULT = "$HOME/Documents/obsidian";
  };

  home.sessionPath = [
    "/etc/profiles/per-user/$USER/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    # Kimi Code's own binary. Must win over $HOME/.local/bin, which still
    # holds an unrelated `uv tool install kimi-cli` shim (also named
    # `kimi`) — see kimi-legacy rename below. Kimi Code's installer tries
    # to self-add this dir to PATH by appending to ~/.zshrc, but that's a
    # home-manager-generated file (read-only nix store symlink), so its
    # `_update_path` step always fails with "Permission denied"; declaring
    # it here is what makes that step a no-op instead (already-in-PATH
    # short-circuit) on future `kimi update` runs.
    "$HOME/.kimi-code/bin"
    "$HOME/.local/bin"
    "/usr/local/bin"
    "$HOME/bin"
    "$HOME/.bun/bin"
    "$HOME/.ghcup/bin"
    "$HOME/.elixir-install/installs/otp/27.3.4/bin"
    "$HOME/.elixir-install/installs/elixir/1.18.4-otp-27/bin"
    "$HOME/.cargo/bin"
    "$HOME/go/bin"
    "$HOME/.opencode/bin"
    "$HOME/.codeium/windsurf/bin"
    "$HOME/.antigravity/antigravity/bin"
    "$HOME/.amp/bin"
    "$HOME/.fabro/bin"
  ] ++ lib.optionals isDarwin [
    "/Applications/Obsidian.app/Contents/MacOS"
  ] ++ [
    "$HOME/.nix-profile/bin"
  ];

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    fileWidget = {
      command = "fd --type f --hidden --exclude .git --color=always";
      options = [
        "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
      ];
    };
    changeDirWidget = {
      command = "fd --type d --hidden --exclude .git --color=always";
      options = [
        "--preview 'eza --tree --level=2 --icons --color=always --no-quotes {}'"
      ];
    };
    defaultOptions = [
      "--height=50%"
      "--layout=reverse"
      "--border"
      "--ansi"
      "--prompt='fzf> '"
      "--pointer='>'"
      "--marker='+'"
      "--color=fg:-1,bg:-1,hl:cyan,fg+:white,bg+:black,hl+:cyan"
      "--color=info:yellow,prompt:cyan,pointer:green,marker:yellow,spinner:green,header:cyan"
    ];
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
    # Trust my own project roots so `cd` never re-prompts with
    # "direnv: error .envrc is blocked. Run 'direnv allow'": that prompt fires
    # on every `.envrc`/flake.lock churn (auto-update commits, switches, merges)
    # and is the recurring "direnv seems broken" symptom. Scoped to dirs I own —
    # deliberately NOT ~/Downloads, where an untrusted repo's .envrc could land.
    config.whitelist.prefix = [
      "${config.home.homeDirectory}/nix-config"
      "${config.home.homeDirectory}/devv"
      "${config.home.homeDirectory}/Burrow"
      "${config.home.homeDirectory}/ghostty"
    ];
    # Drop direnv's noisy `export +VAR … ~VAR` diff on every `cd`/reload — nix
    # dev shells export ~50 vars and the dump dominates the terminal. `log_filter`
    # is an allowlist (only messages matching the regexp are printed), so this
    # keeps the useful `loading`/`using flake`/`nix-direnv` status lines and hides
    # the export diff. Errors bypass the filter, so a blocked/failing .envrc still
    # surfaces.
    config.global.log_filter = "^(loading|using|nix-direnv)";
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd" "z" ];
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "Catppuccin Macchiato";
    };
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = false;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch = {
      enable = true;
      searchUpKey = [
        "^[[A"
        "^P"
      ];
      searchDownKey = [
        "^[[B"
        "^N"
      ];
    };
    defaultKeymap = "emacs";

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

    shellAliases = {
      c = "clear";
      code = "nvim";
      zed = "zeditor";
      zededitor = "zeditor";
      ks = "tmux kill-server";
      scratch = "nvim -c \"setlocal buftype=nofile\"";
      vimdiff = "nvim -d";
      wr = "wrangler";
      lc = "localcode";
      reload = "source ~/.zshrc";

      ls = "eza --icons --git --group-directories-first --hyperlink --no-quotes";
      ll = "eza -lh --icons --git --group-directories-first --hyperlink --no-quotes --color-scale=size --color-scale-mode=gradient --smart-group";
      la = "eza -la --icons --git --group-directories-first --hyperlink --no-quotes --color-scale=size --color-scale-mode=gradient --smart-group";
      lt = "eza -lT --level=2 --icons --hyperlink --no-quotes";
      tree = "eza --tree --icons --git-ignore --hyperlink --no-quotes";
      # lsr (github.com/rockorager/lsr): no git-status/smart-group like eza, but
      # wins decisively on large flat dirs (node_modules, build output, logs) —
      # benchmarked ~2x faster than eza at 1k entries, ~7x at 10k. Kept as a
      # separate alias rather than replacing ls/ll/la since eza is still better
      # for everyday small-dir browsing (git status, color-scale, smart-group).
      lr = "lsr -al --group-directories-first --color=auto --icons=auto --hyperlinks=auto";
      lrt = "lsr --tree --color=auto --icons=auto";
      cat = "bat --paging=never";
      preview = "bat --style=numbers --color=always";
      find = "fd";
      du = "dust";
      ps = "procs";
      top = "btm";

      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      down = "cd ~/Downloads";
      dev = "cd ~/Developer";
      doc = "cd ~/Documents";

      g = "git";
      gst = "git status";
      gd = "git diff";
      gds = "git diff --staged";
      gco = "git checkout";
      gcb = "git checkout -b";
      gb = "git branch";
      gbd = "git branch -d";
      gm = "git merge";
      ga = "git add";
      gaa = "git add --all";
      gc = "git commit -v";
      gcmsg = "git commit -m";
      gcam = "git commit -a -m";
      gamend = "git commit --amend";
      gl = "git pull";
      gp = "git push";
      gpsup = "git push --set-upstream origin $(git branch --show-current)";
      gpf = "git push --force-with-lease";
      glog = "git log --oneline --decorate --graph";
      glol = "git log --graph --pretty='%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'";
      gsta = "git stash push";
      gstp = "git stash pop";
      gstl = "git stash list";

      sg = "ast-grep";
      oxl = "oxlint";
      oxf = "oxfmt";
      oxfix = "oxlint --fix";
      gsp = "ghostty-split";
      gpn = "ghostty-pane";
      pymobiledevice3 = "source ~/.venv/bin/activate && python -m pymobiledevice3";

      mg = "mgrep search";
      mgc = "mgrep search -c";
      mga = "mgrep search -a";
      mgw = "mgrep search -w";
      mgwa = "mgrep search -w -a";
      mgs = "mgrep search -s";

      sudo = "sudo -E";

      npm = "bun";
      npx = "bunx";
      pnpm = "bun";
      p = "bun";
      pn = "pnpm";
      oc = "opencode";

      cct = "cmux claude-teams";
      cdx = "_codex_cli";

      obsidian = "ob";
      ob-remote = "ob sync-list-remote";
      ob-local = "ob sync-list-local";
      ob-status = "ob sync-status";
      ob-config = "ob sync-config";
      ob-sync = "ob sync";
      ob-watch = "ob sync --continuous";
      note = "notesmd-cli";
      note-daily = "notesmd-cli daily --editor";
      note-new = "notesmd-cli create --editor";
      note-find = "notesmd-cli search";
      note-find-content = "notesmd-cli search-content";
      note-ls = "notesmd-cli list";
      note-open = "notesmd-cli open --editor";
      canary-start = "~/.local/bin/canary-debug";
    } // lib.optionalAttrs isDarwin {
      # macOS-only tools and paths; Linux hosts get none of these.
      pbc = "pbcopy";
      pbp = "pbpaste";
      ip = "ipconfig getifaddr en0";
      sync = "sudo darwin-rebuild switch --flake ~/nix-config";
      claude-conductor = "\"$HOME/Library/Application Support/com.conductor.app/bin/claude\"";
    };

    profileExtra = lib.optionalString isDarwin ''
      source ~/.orbstack/shell/init.zsh 2>/dev/null || :
    '';

    envExtra = lib.optionalString isDarwin ''
      export SHELL="/bin/zsh"
    '' + ''
      export BAT_THEME="Catppuccin Macchiato"
      export HOMEBREW_NO_ANALYTICS=1
      export RANGER_LOAD_DEFAULT_RC="FALSE"
      export PNPM_HOME="${pnpmHome}"
      export LESSKEYIN="$HOME/.config/less/.lesskey"
      export LESSHISTFILE="$HOME/.config/less/.lesshst"
      export POWERLINE_NERD_FONTS=1

      export TERMINFO="$HOME/.terminfo"
      typeset -aU _terminfo_dirs
      _terminfo_dirs=(
        ${lib.concatStringsSep "\n        " terminfoDirs}
        ''${(s/:/)TERMINFO_DIRS}
      )
      _terminfo_dirs=(''${_terminfo_dirs:#})
      (( ''${#_terminfo_dirs[@]} > 0 )) && export TERMINFO_DIRS="''${(j/:/)_terminfo_dirs}"
      unset _terminfo_dirs
    '';

    initContent = ''
      _ZSH_CONFIG_DIR="$HOME/.config/zsh"

      setopt AUTO_CD AUTO_MENU COMPLETE_IN_WORD NO_BEEP PROMPT_CR
      setopt HIST_VERIFY INTERACTIVE_COMMENTS HIST_FCNTL_LOCK
      setopt HIST_FIND_NO_DUPS
      unsetopt NOMATCH AUTO_REMOVE_SLASH

      KEYTIMEOUT=1
      HISTORY_SUBSTRING_SEARCH_PREFIXED=1

      [[ -f "$_ZSH_CONFIG_DIR/.secret" ]] && source "$_ZSH_CONFIG_DIR/.secret"

    '' + lib.optionalString isDarwin ''
      if [[ -z "$SDKROOT" ]]; then
        export SDKROOT="$(xcrun --show-sdk-path 2>/dev/null)"
      fi
      [[ -n "$SDKROOT" ]] && {
        export CFLAGS="-isysroot $SDKROOT $CFLAGS"
        export CPPFLAGS="-isysroot $SDKROOT $CPPFLAGS"
      }

    '' + ''
      if (( $+commands[hx] )); then
        export EDITOR=hx VISUAL=hx
      elif (( $+commands[nvim] )); then
        export EDITOR=nvim VISUAL=nvim
      fi

      zmodload zsh/complist
      autoload -Uz edit-command-line; zle -N edit-command-line
      zstyle ":completion:*:*:*:*:*" menu select
      zstyle ":completion:*" use-cache yes
      zstyle ":completion:*" special-dirs true
      zstyle ":completion:*" squeeze-slashes true
      zstyle ":completion:*" file-sort change
      zstyle ":completion:*" matcher-list "m:{[:lower:][:upper:]}={[:upper:][:lower:]}" "r:|=*" "l:|=* r:|=*"

      [[ -f $_ZSH_CONFIG_DIR/tabtab/pnpm.zsh ]] && source $_ZSH_CONFIG_DIR/tabtab/pnpm.zsh

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
      mgsearch() { mgrep search -c -m 20 "$@" }
      webai() { mgrep search -w -a "$@" }

      fif() {
        (( $# )) || return
        rg --files-with-matches --no-messages -- "$1" | \
          FIF_QUERY="$1" fzf \
            --prompt='󰈞 ' \
            --preview 'rg --ignore-case --pretty --context 10 -- "$FIF_QUERY" {}'
      }

      fgb() {
        local branches branch
        branches=$(git branch --all | grep -v 'HEAD') &&
        branch=$(echo "$branches" | fzf --prompt='󱔎 ' --height 50% --layout=reverse --border \
          --preview "git log --oneline --graph --date=short --color=always --pretty='format:%C(auto)%h %C(magenta)%ad %C(cyan)%an %Creset%s' {1} | head -n 20") &&
        git checkout "$(echo "$branch" | sed 's/.* //; s#remotes/[^/]*/##')"
      }

      fgl() {
        git log --graph --color=always --format="%C(auto)%h%d %s %C(black)%C(bold)%cr" "$@" |
        fzf --prompt='󰊚 ' --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-s:toggle-sort \
          --bind "ctrl-m:execute:
            (grep -o '[a-f0-9]\{7\}' | head -1 |
            xargs -I % sh -c 'git show --color=always % | less -R') << 'FZF-EOF'
            {}
      FZF-EOF" \
          --preview "grep -o '[a-f0-9]\{7\}' <<< {} | xargs git show --color=always"
      }

      fkill() {
        local pid
        pid=$(ps -ef | sed 1d | fzf --prompt='󰆙 ' -m | awk '{print $2}')
        [[ -n "$pid" ]] && echo "$pid" | xargs -r kill "-''${1:-9}"
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

      [ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"
      [ -f "''${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env" ] && source "''${GHCUP_INSTALL_BASE_PREFIX:=$HOME}/.ghcup/env"
      [[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
      (( $+commands[mole] )) && eval "$(mole completion zsh)"
      [[ -f "$HOME/.local/try.rb" ]] && eval "$(ruby ~/.local/try.rb init ~/src/tries)"

      if [[ -x "$HOME/.local/bin/update-ai-tools" ]]; then
        ("$HOME/.local/bin/update-ai-tools" --check >/dev/null 2>&1 &)
      fi

      [[ -r $_ZSH_CONFIG_DIR/cmux.zsh ]] && source $_ZSH_CONFIG_DIR/cmux.zsh

      [[ -f $_ZSH_CONFIG_DIR/function.zsh ]] && source $_ZSH_CONFIG_DIR/function.zsh

      _show_terminal_tip() {
        [[ $- != *i* ]] && return
        local -a tips
        tips+=(
          "[zsh] Press %F{yellow}CTRL-R%f to fuzzy-search history -- much faster than tapping the up arrow."
          "[zsh] Type a command prefix (e.g. %F{green}ssh%f) then press %F{yellow}up%f to navigate only matching history."
          "[zsh] After editing config, run %F{green}reload%f to apply all changes immediately."
          "[zsh] %F{green}AUTO_CD%f is enabled: type a directory name to cd into it without typing cd."
          "[zsh] %F{green}CDPATH%f is set: jump to ~/Developer, ~/Downloads, ~/Documents dirs by name."
        )
        if (( $+commands[fzf] )); then
          tips+=(
            "[fzf] Press %F{yellow}CTRL-T%f to search files and paste the path to the command line."
            "[fzf] Press %F{yellow}ALT-C%f to fuzzy-search subdirectories and cd into one instantly."
            "[fzf] Run %F{green}fkill%f to interactively find and kill a process by name."
            "[fzf] Run %F{green}fif <keyword>%f to search file contents interactively across the current directory."
          )
        fi
        if (( $+commands[fd] )); then
          tips+=("[fd] fd is much faster than find and ignores .git and .gitignore entries by default.")
        fi
        if (( $+commands[rg] )); then
          tips+=("[rg] ripgrep is blazing fast. Use %F{green}rg -t py 'pattern'%f to search only Python files.")
        fi
        if (( $+commands[eza] )); then
          tips+=(
            "[eza] Your %F{green}ls/ll%f aliases use eza -- with icons, git status, and directories first."
            "[eza] Run %F{green}tree%f for a modern directory tree with icons and colors."
          )
        fi
        if (( $+commands[bat] )); then
          tips+=("[bat] Your %F{green}cat%f is aliased to bat -- syntax highlighting, line numbers, and git change markers included.")
        fi
        if (( $+commands[jj] )); then
          tips+=("[jj] Run %F{green}jj diff%f for delta-highlighted hunks, and %F{green}jj split%f / %F{green}jj squash -i%f for interactive hunk review.")
        fi
        if (( $+commands[zoxide] )); then
          tips+=("[zoxide] Use %F{green}z <partial-name>%f to jump to frequently visited directories.")
        fi
        if (( $+commands[claude] )); then
          tips+=(
            "[AI] Claude has %F{cyan}agent-teams%f experimental feature enabled -- great for complex multi-step tasks."
            "[AI] Run %F{green}cc%f for Claude with skip-permissions, %F{green}cofficial%f for clean env."
          )
        fi
        if (( $+commands[mgrep] )); then
          tips+=(
            "[mgrep] Run %F{green}mg 'query'%f for semantic code search, %F{green}mgw%f for web search."
            "[mgrep] Use %F{green}webai 'topic'%f for web search + AI summary."
          )
        fi
        if (( $+commands[ast-grep] )); then
          tips+=("[ast-grep] Use %F{green}sg%f for structural code search using AST patterns -- more precise than regex.")
        fi
        if (( $+commands[git] )); then
          tips+=(
            "[Git] Use %F{green}fgb%f for interactive branch switching with a live commit preview."
            "[Git] Run %F{green}fgl%f for an interactive git log -- select a commit to view its diff."
            "[Git] Use %F{green}gpf%f (push --force-with-lease) for a safer force push."
          )
        fi
        if (( $+commands[gh] )); then
          tips+=(
            "[gh] Use %F{green}gh pr list%f to view open PRs, or %F{green}gh issue status%f to check your issues."
            "[gh] Run %F{green}gh repo view --web%f to open the current GitHub repo in your browser."
          )
        fi
        if (( $+commands[pnpm] )); then
          tips+=("[bun] Your %F{green}p%f, %F{green}npm%f, %F{green}npx%f, and %F{green}pnpm%f shims route through bun/bunx.")
        fi
        local index=$(( RANDOM % ''${#tips[@]} + 1 ))
        print -P "\n%F{cyan}''${tips[$index]}%f"
      }
      [[ "''${MARTIN_SHOW_TERMINAL_TIPS:-0}" == "1" ]] && _show_terminal_tip

      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
      fi

      [[ -r $HOME/.zshrc.local ]] && source $HOME/.zshrc.local
      unset _ZSH_CONFIG_DIR
    '';
  };
}
