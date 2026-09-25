{ config, lib, pkgs, ... }:

let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  viMode = config.martin.shell.viMode;
  search = config.martin.shell.search;

  gitPlaneOn = search.enable && search.gitObjects.enable;
  fzfPlaneOn = search.enable && (config.programs.fzf.enable or false);
  zoxidePlaneOn = search.enable && (config.programs.zoxide.enable or false);

  shared = import ./shared.nix { inherit lib isDarwin; };

  # Fish binds normal mode as "default"; vi mode adds "insert".
  modes = [ "default" ] ++ lib.optional viMode.enable "insert";
  bindAll = key: command:
    lib.concatMapStringsSep "\n" (mode: "bind -M ${mode} ${key} ${command}") modes;

  # "^G" -> "ctrl-g", fish 4 key notation.
  prefix = "ctrl-" + lib.toLower (lib.removePrefix "^" search.prefix);

  quotedTerminfoDirs = lib.concatMapStringsSep " " (d: ''"${d}"'') shared.terminfoDirs;
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf (config.martin.shell.interactive == "fish") {
    home.packages = lib.optionals gitPlaneOn [
      pkgs.fzf-git-sh
    ];

    programs.fish = {
      enable = true;

      # Man-page completions build one derivation per package, which the
      # auto-update source-build guard treats as source builds. Fish's own
      # completions and each package's vendor completions still load.
      generateCompletions = false;

      shellAbbrs = shared.aliases // {
        grep = "rg";
        reload = "exec fish";
        pymobiledevice3 = "source ~/.venv/bin/activate.fish && python -m pymobiledevice3";
        # `..`, `...`, `....`: each extra dot climbs one more directory.
        dotdot = {
          regex = "^\\.\\.+$";
          function = "__martin_multicd";
        };
      };

      # Every fish process, like .zshenv: keep inherited terminfo and a
      # duplicate-free PATH in the tier order hm-session-vars just applied.
      shellInit = ''
        set -gx TERMINFO "$HOME/.terminfo"
        set -l terminfo_dirs
        for d in ${quotedTerminfoDirs} (string split : -- "$TERMINFO_DIRS")
            if test -n "$d"; and not contains -- $d $terminfo_dirs
                set -a terminfo_dirs $d
            end
        end
        set -gx TERMINFO_DIRS (string join : -- $terminfo_dirs)

        set -l unique_path
        for p in $PATH
            contains -- $p $unique_path; or set -a unique_path $p
        end
        set -gx PATH $unique_path
      '';

      loginShellInit = lib.optionalString isDarwin ''
        test -r ~/.orbstack/shell/init2.fish; and source ~/.orbstack/shell/init2.fish
      '';

      interactiveShellInit = lib.mkMerge [
        # Before fzf's bindings (order 200), so every later bind lands in the
        # final keymap set.
        (lib.mkOrder 100 ''
          set -g fish_greeting
          set -g fish_key_bindings ${if viMode.enable then "fish_vi_key_bindings" else "fish_default_key_bindings"}
        '')

        (lib.optionalString viMode.enable ''
          # Emacs reflexes in vi insert mode; fish already binds ctrl-k and ctrl-w.
          bind -M insert ctrl-a beginning-of-line
          bind -M insert ctrl-e end-of-line
          bind -M insert ctrl-u kill-whole-line
          bind -M insert ctrl-p up-or-search
          bind -M insert ctrl-n down-or-search
        '')

        (lib.optionalString gitPlaneOn ''
          source ${pkgs.fzf-git-sh}/share/fzf-git-sh/fzf-git.fish
          # Plain letters under the prefix belong to this repo's pickers; the
          # ctrl-letter git chords stay.
          for mode in default insert
              for k in b t r h s l e w
                  bind -e -M $mode ${prefix},$k
              end
          end
        '')

        (lib.optionalString (fzfPlaneOn && search.keys.contentSearch != null)
          (bindAll "${prefix},${search.keys.contentSearch}" "martin-content-search"))
        (lib.optionalString (fzfPlaneOn && search.keys.processKill != null)
          (bindAll "${prefix},${search.keys.processKill}" "martin-process-kill"))
        (lib.optionalString (zoxidePlaneOn && search.keys.dirJump != null)
          (bindAll "${prefix},${search.keys.dirJump}" "martin-dir-jump"))

        # Helpers that shadow a real command are defined here, not autoloaded,
        # so fish scripts and `fish -c` still find the real command.
        ''
          function du --wraps dust -d 'du flags translated for dust: -h is implied, -s means depth 0'
              set -l args
              for a in $argv
                  if string match -qr -- '^-[a-zA-Z]' $a
                      set a (string replace -a h "" -- $a)
                      if string match -q -- '*s*' $a
                          set a (string replace -a s "" -- $a)
                          set -a args -d 0
                      end
                      test "$a" = -; and continue
                  end
                  set -a args $a
              end
              command dust $args
          end

          function ab -d 'Run agent-browser, starting Chrome Canary for CDP when needed'
              if not curl -s http://localhost:9222/json/version >/dev/null 2>&1
                  ~/.local/bin/canary-debug >/dev/null 2>&1
              end
              agent-browser $argv
          end
        ''
      ];

      functions = {
        # Directory name and a status-colored arrow. Builtins only, so the
        # prompt never waits on an external command. The arrow points left in
        # vi normal mode.
        fish_prompt = ''
          set -l last_status $status
          set -l arrow '❯'
          if test "$fish_key_bindings" = fish_vi_key_bindings; and test "$fish_bind_mode" != insert
              set arrow '❮'
          end
          set -l arrow_color green
          test $last_status -ne 0; and set arrow_color red
          set -l dir (path basename -- $PWD)
          test "$PWD" = "$HOME"; and set dir '~'
          test "$PWD" = /; and set dir /
          printf '%s%s%s %s%s%s ' (set_color cyan) $dir (set_color normal) (set_color $arrow_color) $arrow (set_color normal)
        '';

        # The prompt arrow already shows the vi mode.
        fish_mode_prompt = "";

        __martin_multicd = ''
          echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
        '';

        martin-content-search = {
          description = "Search plane: replace the current token with a file whose content matches it";
          body = ''
            set -l query (commandline --current-token)
            if test -z "$query"
                echo
                echo 'search plane: type a search term first, then press the chord again'
                commandline -f repaint
                return
            end
            set -l sel (fif $query)
            if test -n "$sel"
                commandline --current-token --replace -- (string escape -- $sel)
            end
            commandline -f repaint
          '';
        };

        martin-dir-jump = {
          description = "Search plane: jump to a zoxide directory";
          body = ''
            set -l dir (command zoxide query -i)
            test -n "$dir"; and cd -- $dir
            commandline -f repaint
          '';
        };

        martin-process-kill = {
          description = "Search plane: pick processes to kill";
          body = ''
            fkill
            commandline -f repaint
          '';
        };

        fif = {
          description = "Pick a file whose content matches a ripgrep pattern";
          body = ''
            set -q argv[1]; or return
            rg --files-with-matches --no-messages -- $argv[1] | FIF_QUERY=$argv[1] fzf \
                --prompt='󰈞 ' \
                --preview 'rg --ignore-case --pretty --context 10 -- "$FIF_QUERY" {}'
          '';
        };

        fkill = {
          description = "Pick processes with fzf and signal them (default 9)";
          body = ''
            set -l signal 9
            set -q argv[1]; and set signal $argv[1]
            set -l pids (command ps -ef | sed 1d | fzf --prompt='󰆙 ' -m | awk '{print $2}')
            test -n "$pids"; and kill -$signal $pids
          '';
        };

        dev-info = {
          description = "Show the active VCS and toolchain versions";
          body = ''
            set -l out
            if command -q git; and command git rev-parse --is-inside-work-tree >/dev/null 2>&1
                set -a out "git:$(command git branch --show-current 2>/dev/null)"
            end
            if command -q jj; and command jj root >/dev/null 2>&1
                set -a out "jj:$(command jj log -r @ -n 1 --no-graph -T 'change_id.shortest(6)' 2>/dev/null)"
            end
            command -q node; and set -a out "node:$(command node -v 2>/dev/null)"
            command -q bun; and set -a out "bun:$(command bun -v 2>/dev/null)"
            command -q python3; and set -a out "py:$(command python3 -V 2>/dev/null | string split -f2 ' ')"
            command -q rustc; and set -a out "rust:$(command rustc -V 2>/dev/null | string split -f2 ' ')"
            command -q go; and set -a out "go:$(command go version 2>/dev/null | string split -f3 ' ')"
            echo (set_color cyan)(string join (set_color white)' | '(set_color cyan) $out)(set_color normal)
          '';
        };

        _ghostty_key = ''
          if not command -q skhd
              echo "ghostty: skhd is not on PATH; run sync or use Ghostty's native keybinds" >&2
              return 127
          end
          command skhd -k $argv[1]
        '';

        ghostty-split = {
          description = "Split the Ghostty pane: right, down, zoom, or equal";
          body = ''
            set -l action right
            set -q argv[1]; and set action $argv[1]
            switch $action
                case right r east e
                    _ghostty_key 'cmd - d'
                case down d south s
                    _ghostty_key 'cmd + shift - d'
                case zoom z
                    _ghostty_key 'cmd + shift - f'
                case equal eq 0
                    _ghostty_key 'cmd + shift - 0'
                case '*'
                    echo 'usage: ghostty-split {right|down|zoom|equal}' >&2
                    return 2
            end
          '';
        };

        ghostty-pane = {
          description = "Move between Ghostty panes: left, right, up, or down";
          body = ''
            set -l action left
            set -q argv[1]; and set action $argv[1]
            switch $action
                case left h west w
                    _ghostty_key 'cmd + alt - left'
                case right l east e
                    _ghostty_key 'cmd + alt - right'
                case up k north n
                    _ghostty_key 'cmd + alt - up'
                case down j south s
                    _ghostty_key 'cmd + alt - down'
                case '*'
                    echo 'usage: ghostty-pane {left|right|up|down}' >&2
                    return 2
            end
          '';
        };
      };
    };
  };
}
