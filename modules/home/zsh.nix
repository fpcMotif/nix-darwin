{ config, lib, pkgs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  viMode = config.martin.shell.viMode;
  search = config.martin.shell.search;

  # The upstream fzf-git.sh half of the plane: sourced, re-registered after
  # zsh-vi-mode's keymap reset, and packaged. Everything it gates shares one
  # reason, so the predicate is spelled once.
  gitPlaneOn = search.enable && search.gitObjects.enable;

  # Plugin cursor names -> the ZVM_*_MODE_CURSOR codes they map to.
  viCursorCode = {
    block = "bl";
    underline = "ul";
    beam = "be";
    blinking-block = "bbl";
    blinking-underline = "bul";
    blinking-beam = "bbe";
  };

  # `toString` renders floats with six decimals (0.050000); trim trailing
  # zeros so the generated zshrc looks hand-written. Same precedent as
  # modules/home/ghostty.nix.
  trimZeros = s:
    if lib.hasSuffix "0" s && lib.stringLength s > 1 then
      trimZeros (lib.substring 0 (lib.stringLength s - 1) s)
    else
      s;

  formatFloat = f:
    let
      s = toString f;
      trimmed = if lib.hasInfix "." s then trimZeros s else s;
    in
    if lib.hasSuffix "." trimmed then trimmed + "0" else trimmed;
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
  # Vi line editing at the prompt -- see CONTEXT.md "Prompt vi mode". The
  # surface is zsh's ZLE, so it applies identically in Ghostty, kitty, tmux,
  # and over ssh with no per-terminal configuration.
  options.martin.shell.viMode = {
    enable = lib.mkEnableOption "vi editing at the zsh prompt via the zsh-vi-mode plugin" // {
      default = true;
    };

    cursor = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Per-mode DECSCUSR cursor shapes (drives ZVM_CURSOR_STYLE_ENABLED).";
      };

      insert = lib.mkOption {
        type = lib.types.enum (lib.attrNames viCursorCode);
        default = "beam";
        description = "Cursor shape in insert mode.";
      };

      normal = lib.mkOption {
        type = lib.types.enum (lib.attrNames viCursorCode);
        default = "block";
        description = "Cursor shape in normal mode.";
      };

      visual = lib.mkOption {
        type = lib.types.enum (lib.attrNames viCursorCode);
        default = "block";
        description = "Cursor shape in visual mode.";
      };
    };

    escapeDelay = lib.mkOption {
      type = lib.types.float;
      default = 0.05;
      description = ''
        Escape-sequence window in seconds, driving ZVM_KEYTIMEOUT -- the
        plugin's own multi-key handling. This is not zsh's KEYTIMEOUT.
      '';
    };

    escapeSequence = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "jk";
      description = ''
        Insert-mode escape chord (ZVM_VI_INSERT_ESCAPE_BINDKEY). null keeps
        plain Escape.
      '';
    };

    keepEmacsKeys = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Re-apply ^A ^E ^K ^U ^W into viins after the plugin loads, keeping
        the emacs reflexes that still work without leaving insert mode.
        (^P and ^N are not part of this toggle: the core contract re-binds
        them to the prefix-history widgets in BOTH keymaps regardless, per
        the Up/Down requirement.)
      '';
    };
  };
  # Prompt search plane -- see CONTEXT.md "Prompt search plane". The prefix
  # is a chord over zsh's ZLE, so it works identically in Ghostty, kitty,
  # tmux, and over ssh. martin.terminal.ghostty.search (opt-in) only TYPES
  # the same chords; this module owns their meaning.


  options.martin.shell.search = {
    enable = lib.mkEnableOption "the prompt search plane: a ^G-prefixed zsh key plane over the fzf pickers" // {
      default = true;
    };

    prefix = lib.mkOption {
      type = lib.types.str;
      default = "^G";
      description = ''
        Search-plane prefix in two-character caret form ("^G"). It is
        explicitly removed from every keymap the plane binds, keeping it a
        PURE prefix: with KEYTIMEOUT=1 an ambiguously bound prefix makes
        two-key chords untypable.
      '';
    };

    gitObjects.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Source fzf-git.sh and install its ^G CTRL-key plane (files,
        branches, tags, remotes, hashes, stashes, reflogs, each-ref,
        worktrees). Upstream also self-binds plain-letter fallback forms;
        this module strips those back out so the namespace split holds:
        CTRL-key belongs to upstream, plain letters to this repo.
      '';
    };

    keys = lib.mkOption {
      type = lib.types.submodule {
        options = {
          contentSearch = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "f";
            description = "Letter for the ripgrep content picker (inserts the path at cursor); null unbinds.";
          };

          dirJump = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "d";
            description = "Letter for the zoxide interactive directory jump; null unbinds.";
          };

          processKill = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = "k";
            description = "Letter for the process kill picker; null unbinds.";
          };
        };
      };
      default = { };
      description = "Plain letters under the prefix for this repo's pickers.";
    };
  };

  # Everything below is configuration; the module also declares options
  # above, so the module system requires this explicit `config` attribute.
  config = {
    home.packages = lib.optionals gitPlaneOn [
      pkgs.fzf-git-sh
    ];

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
      completionInit = ''
        fpath=($HOME/.zsh/completions $fpath)
        autoload -U compinit && compinit
      '';
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      # Up/Down history search is the native zle prefix widget (bound in
      # initContent), not zsh-history-substring-search: the plugin matches
      # anywhere in the line and splits the query on spaces into `a*b*` globs,
      # so `git p` hits `git commit -p`. Ctrl-R (fzf) covers fuzzy search.
      historySubstringSearch.enable = false;
      # Belt-and-braces with the plugin's own `bindkey -v`: if the plugin ever
      # fails to load the shell still lands in vi mode, and Starship's zsh
      # keymap detection has something to read. Disabling viMode restores emacs.
      defaultKeymap = if viMode.enable then "viins" else "emacs";

      plugins = lib.optionals viMode.enable [
        {
          name = "zsh-vi-mode";
          src = pkgs.zsh-vi-mode;
          file = "share/zsh-vi-mode/zsh-vi-mode.plugin.zsh";
        }
      ];

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

        npm = "bun";
        npx = "bunx";
        pnpm = "bun";
        p = "bun";
        oc = "opencode";

        cct = "cmux claude-teams --dangerously-skip-permissions";
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

      initContent = lib.mkMerge [
        # Order 880: must land BEFORE home-manager sources programs.zsh.plugins
        # (order 900). The plugin reads every ZVM_* variable when its file is
        # sourced, and under ZVM_INIT_MODE=sourcing zvm_init consumes
        # zvm_after_init_commands at source time -- registering any later would
        # register into a hook that has already run. The plain user init below
        # is the default-order (1000) member of this merge.
        (lib.mkOrder 880 ''
          ${lib.optionalString gitPlaneOn ''
            # Free ^S/^Q from terminal flow control so fzf-git.sh's stash
            # picker (^G^S) works; upstream requirement, no downside today.
            # Interactive guard: zshrc fragments can run with stdin off a tty.
            [[ -o interactive ]] && command stty -ixon 2>/dev/null || :
          ''}
          ${lib.optionalString gitPlaneOn ''
            source "${pkgs.fzf-git-sh}/share/fzf-git-sh/fzf-git.sh"
            # Upstream binds at source time; zsh-vi-mode resets keymaps after
            # that, so re-register its init to run INSIDE the plugin's hook.
            # Registered BEFORE _martin_zle_binds_vi below, which then binds
            # this repo's plain letters -- configured letters win collisions
            # by hook ordering (upstream's own '^g<letter>' fallback forms).
            zvm_after_init_commands+=( _martin_fzf_git_rebind )
          ''}

          ${lib.concatStringsSep "\n"
            (lib.optionals viMode.enable (
              [
                "export ZVM_INIT_MODE=sourcing       # initialize when sourced, not at first prompt"
                "export ZVM_LAZY_KEYBINDINGS=false   # bind vicmd/visual eagerly: deterministic keymap tables"
                "export ZVM_CURSOR_STYLE_ENABLED=${if viMode.cursor.enable then "true" else "false"}"
                "export ZVM_INSERT_MODE_CURSOR=${viCursorCode.${viMode.cursor.insert}}"
                "export ZVM_NORMAL_MODE_CURSOR=${viCursorCode.${viMode.cursor.normal}}"
                "export ZVM_VISUAL_MODE_CURSOR=${viCursorCode.${viMode.cursor.visual}}"
                "export ZVM_KEYTIMEOUT=${formatFloat viMode.escapeDelay}   # plugin escape window, NOT zsh KEYTIMEOUT"
              ]
              ++ lib.optionals (viMode.escapeSequence != null) [
                "export ZVM_VI_INSERT_ESCAPE_BINDKEY='${viMode.escapeSequence}'"
              ]
              ++ [
                "_martin_vi_mode=1"
                "zvm_after_init_commands+=( _martin_zle_binds_vi )"
              ]
            ))}

          # Widget prep shared by both keymap regimes; must run before the
          # bindings do (the plugin's init hook, in vi mode).
          zmodload zsh/complist
          autoload -Uz edit-command-line
          zle -N edit-command-line
          zmodload -i zsh/terminfo 2>/dev/null
          autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
          zle -N up-line-or-beginning-search
          zle -N down-line-or-beginning-search

          ${lib.optionalString gitPlaneOn ''
            # Re-run fzf-git.sh's own installer after zsh-vi-mode's keymap
            # reset. stderr is silenced: under vi mode upstream also binds
            # into the emacs keymap, which may not exist post-reset.
            _martin_fzf_git_rebind() {
              (( $+functions[__fzf_git_init] )) || return
              __fzf_git_init files branches tags remotes hashes stashes lreflogs each_ref worktrees '?list_bindings' 2>/dev/null
            }
          ''}

          ${lib.optionalString search.enable ''
            # Prompt search plane widgets, two behavioral classes.
            # Insert-into-buffer: content search pastes the selected path at
            # the cursor; the rest of the typed line stays untouched, and a
            # cancel is a no-op on the buffer. Run-and-restore: dir jump /
            # process kill take their side effect, then zle -I discards any
            # stray child output before reset-prompt redraws the prompt with
            # the half-typed line intact. The pickers themselves are fif,
            # fkill and zoxide unchanged -- this adds keys, not behavior.
            martin-content-search-widget() {
              local query sel
              # Seed the query from the word before the cursor; ZLE cannot
              # nest vared for an interactive fallback, so with nothing typed
              # there we hint and return instead of blocking.
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

            martin-dir-jump-widget() {
              local dir
              dir=$(command zoxide query -i)
              zle -I
              [[ -n "$dir" ]] && builtin cd "$dir"
              zle reset-prompt
            }

            martin-process-kill-widget() {
              fkill
              zle -I
              zle reset-prompt
            }

            zle -N martin-content-search-widget
            zle -N martin-dir-jump-widget
            zle -N martin-process-kill-widget
          ''}

          # Every keybinding this repo owns, placed into EXPLICIT keymaps.
          # In emacs mode they land in the only interactive keymap there is;
          # in vi mode the plugin resets all keymaps when it initializes, so
          # the same function re-runs afterwards via the registered hook --
          # that ordering is the entire point of this shape. $1 selects the
          # keymap list: "emacs", or "viins:vicmd".
          _martin_zle_binds() {
            local kms=$1
            _bindk() {
              local widget=$1 kms=$2 k m
              shift 2
              for m in ''${(s.:.)kms}; do
                for k in "$@"; do [[ -n $k ]] && _martin_bk "$m" "$k" "$widget"; done
              done
            }
            # Prefer the plugin's own binding function so its keymap
            # bookkeeping stays consistent with what is actually bound; fall
            # back to raw bindkey when vi mode is off and the plugin is absent.
            _martin_bk() {
              if (( $+functions[zvm_bindkey] )); then
                zvm_bindkey "$@"
              else
                bindkey -M "$1" -- "$2" "$3"
              fi
            }
            _bindk up-line-or-beginning-search    "$kms" "''${terminfo[kcuu1]}" '^[[A' '^[OA' '^P'
            _bindk down-line-or-beginning-search  "$kms" "''${terminfo[kcud1]}" '^[[B' '^[OB' '^N'
            _bindk delete-char                    "$kms" "''${terminfo[kdch1]}" '^[[3~'
            _bindk beginning-of-line              "$kms" "''${terminfo[khome]}" '^[[H' '^[OH' '^[[1~'
            _bindk end-of-line                    "$kms" "''${terminfo[kend]}"  '^[[F' '^[OF' '^[[4~'
            _bindk beginning-of-buffer-or-history "$kms" "''${terminfo[kpp]}"   '^[[5~'
            _bindk end-of-buffer-or-history       "$kms" "''${terminfo[knp]}"   '^[[6~'
            _bindk reverse-menu-complete          "$kms" "''${terminfo[kcbt]}"  '^[[Z'
            _bindk backward-word                  "$kms" '^[[1;5D' '^[[1;3D' '^[^[[D'
            _bindk forward-word                   "$kms" '^[[1;5C' '^[[1;3C' '^[^[[C'
            _bindk kill-word                      "$kms" '^[[3;5~' '^[[3;3~'
            _bindk backward-kill-word             "$kms" '^[^?'

            ${lib.optionalString search.enable (
              lib.concatStringsSep "\n" (
                [
                  "local m"
                  "# martin.shell.search -- chords first: zvm_bindkey raw-binds the full"
                  "# two-key chord AND registers the chord's first key as its NEX"
                  "# readkeys handler. THEN strip the prefix from every keymap so the"
                  "# FINAL state is a pure prefix: the chords keep working through zsh's"
                  "# own multi-key sequences, zsh waits indefinitely for the second key,"
                  "# and this config's KEYTIMEOUT=1 never races the plane."
                ]
                ++ lib.optionals (search.keys.contentSearch != null) [
                  "_bindk martin-content-search-widget \"$kms\" '${search.prefix}${search.keys.contentSearch}'"
                ]
                ++ lib.optionals (search.keys.dirJump != null) [
                  "_bindk martin-dir-jump-widget \"$kms\" '${search.prefix}${search.keys.dirJump}'"
                ]
                ++ lib.optionals (search.keys.processKill != null) [
                  "_bindk martin-process-kill-widget \"$kms\" '${search.prefix}${search.keys.processKill}'"
                ]
                ++ [
                  "for m in \${(s.:.)kms}; do bindkey -rM \"$m\" -- '${search.prefix}' 2>/dev/null; done"
                ]
                ++ lib.optionals search.gitObjects.enable (
                  let
                    configuredKeys = lib.filter (k: k != null) [
                      search.keys.contentSearch
                      search.keys.dirJump
                      search.keys.processKill
                    ];
                    # Initials of every upstream object type; configured repo
                    # letters are re-bound right above, the rest must go or
                    # upstream keeps owning half the plain-letter space.
                    upstreamLetters = lib.subtractLists configuredKeys
                      [ "f" "b" "t" "r" "h" "s" "l" "e" "w" ];
                  in [
                    "# fzf-git.sh also self-binds PLAIN-letter fallbacks; take the plain"
                    "# half back so the split holds by construction: CTRL-key upstream,"
                    "# plain letters this repo ('?' help stays -- it lists upstream's plane)."
                    "for m in \${(s.:.)kms}; do for k in ${lib.concatStringsSep " " upstreamLetters}; do bindkey -rM \"$m\" -- '${search.prefix}'\"$k\" 2>/dev/null; done; done"
                  ]
                )
              )
            )}

            unset -f _bindk

            if [[ $kms != emacs ]]; then
              # Type a prefix (e.g. `git `) and press Up: cycles only history
              # entries literally STARTING with it, keeping the typed prefix
              # and parking the cursor at end of line. Inside a multiline
              # buffer up/down still move by line. Both ^[[A and ^[OA are bound
              # so this works in normal and application cursor-key mode.
              ${lib.concatStringsSep "\n" (lib.optionals viMode.keepEmacsKeys [
                "_martin_bk viins '^A' beginning-of-line"
                "_martin_bk viins '^E' end-of-line"
                "_martin_bk viins '^K' kill-line"
                "_martin_bk viins '^U' kill-whole-line"
                "_martin_bk viins '^W' backward-kill-word"
              ])}

              # The editor chord: vv from normal mode, ^X^E straight from
              # insert (^X is an unbound pure prefix in viins, so no key-timeout
              # ambiguity). Bare v keeps the plugin's visual mode.
              _martin_bk vicmd 'vv' edit-command-line
              _martin_bk viins '^X^E' edit-command-line

              # fzf's script self-binds emacs/vicmd/viins whenever it runs.
              # Re-assert only when its widgets already exist, so the contract
              # holds no matter which side of the plugin fzf integration lands
              # on in the generated zshrc.
              for km in viins vicmd; do
                (( $+widgets[fzf-history-widget] )) &&
                  _martin_bk "$km" '^R' fzf-history-widget
                (( $+widgets[fzf-file-widget] )) &&
                  _martin_bk "$km" '^T' fzf-file-widget
                (( $+widgets[fzf-cd-widget] )) &&
                  _martin_bk "$km" '^[c' fzf-cd-widget
              done

              # The plugin's re-initialization can detach autosuggestions;
              # make sure its start hook is still queued (no-op when intact).
              if (( $+functions[_zsh_autosuggest_start] )) &&
                ! (( ''${precmd_functions[(I)_zsh_autosuggest_start]} )); then
                precmd_functions+=(_zsh_autosuggest_start)
              fi
            fi
          }

          # The plugin's hook runner word-splits each entry, so the keyed-up
          # variant travels as a bare function name (upstream contract).
          _martin_zle_binds_vi() { _martin_zle_binds viins:vicmd; }
        '')

        (''
          _ZSH_CONFIG_DIR="$HOME/.config/zsh"

          setopt AUTO_CD AUTO_MENU COMPLETE_IN_WORD NO_BEEP PROMPT_CR
          setopt HIST_VERIFY INTERACTIVE_COMMENTS HIST_FCNTL_LOCK
          setopt HIST_FIND_NO_DUPS
          unsetopt NOMATCH AUTO_REMOVE_SLASH

          # Governs zsh's own multi-key sequence window (this is what keeps
          # Escape instant). The plugin's escape timing is separate:
          # ZVM_KEYTIMEOUT via martin.shell.viMode.escapeDelay. Not the same knob.
          KEYTIMEOUT=1

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

          # All owned ZLE bindings live in _martin_zle_binds (defined above).
          # With vi mode off it runs right here, into the emacs keymap, exactly
          # as before; with vi mode on the plugin's init hook already ran it
          # after its keymap reset, so nothing left to do in this position.
          if [[ ''${_martin_vi_mode:-0} != 1 ]]; then
            _martin_zle_binds emacs
            unset -f _martin_zle_binds
          fi
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

          # du routes to dust as a function, not an alias: `du = "dust"` made
          # `du -sh` expand to `dust -sh`, and dust parses -h as --help (its -s
          # is --apparent-size). Drop h from short-flag clusters (dust is
          # human-readable by default) and map du's -s to dust's -d 0.
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


          # fgb/fgl are retired: fzf-git.sh (search plane, ^G^B / ^G^L)
          # replaces them with previews, multi-select, and nine object types.

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
          [[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"
          (( $+commands[mole] )) && eval "$(mole completion zsh)"
          [[ -f "$HOME/.local/try.rb" ]] && eval "$(ruby ~/.local/try.rb init ~/src/tries)"

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
                ${lib.optionalString (search.enable && search.keys.processKill != null)
                  "\"[fzf] Press %F{yellow}${search.prefix} ${search.keys.processKill}%f to find and kill a process by name (fkill).\""}
                ${lib.optionalString (search.enable && search.keys.contentSearch != null)
                  "\"[fzf] Press %F{yellow}${search.prefix} ${search.keys.contentSearch}%f to search file contents interactively (fif) -- type the search term first.\""}
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
            if (( $+commands[ast-grep] )); then
              tips+=("[ast-grep] Use %F{green}sg%f for structural code search using AST patterns -- more precise than regex.")
            fi
            if (( $+commands[git] )); then
              tips+=(
                # Upstream owns ^G permanently, so this chord text is not an
                # option copy -- it only exists when the git half is installed.
                ${lib.optionalString gitPlaneOn
                  "\"[Git] Press %F{yellow}^G^B%f to pick a branch interactively -- %F{green}^G ?%f lists the full git-object plane.\""}
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
        '')
      ];
    };
  };
}
