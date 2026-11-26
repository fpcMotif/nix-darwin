{ config, lib, ... }:

let
  cfg = config.martin.prompt.starship;

  palette = {
    blue = "#31748F";
    cyan = "#9CCFD8";
    orange = "#EA9A97";
    yellow = "#F6C177";
    lavender = "#C4A7E7";
    green = "#A3BE8C";
    red = "#EB6F92";
    dark = "#232136";
    light = "#E0DEF4";
  };

  pill = { bg, fg ? palette.dark, content }:
    if cfg.palette.enable && cfg.powerline.enable then
      "[](fg:${bg})[${content}](fg:${fg} bg:${bg})[](fg:${bg}) "
    else if cfg.palette.enable then
      "[${content}](fg:${fg} bg:${bg}) "
    else
      "[${content}](bold) ";

  plainStyle = color:
    if cfg.palette.enable then "fg:${color}" else "bold";

  noVcsWhen = ''d=$PWD; while [ -n "$d" ]; do [ -e "$d/.jj" ] || [ -e "$d/.git" ] && exit 1; d=''${d%/*}; done; exit 0'';

  pathBg = palette.orange;
  vcsBg = palette.yellow;
  jjBg = palette.lavender;

  powerStart = bg: "[](fg:${bg})";
  powerJoin = from: to: "[](fg:${from} bg:${to})";
  powerEnd = bg: "[](fg:${bg}) ";
  customShell = [ "/bin/sh" ];

  promptSuccess = "[❯](fg:${palette.cyan}) ";

  promptError = "[❯](fg:${palette.red}) ";

  promptVim = "[❮](fg:${palette.blue}) ";

  rootIndicatorCustom = lib.optionalAttrs cfg.segments.rootIndicator.enable {
    root_indicator = {
      description = "Small warning chip when running as root (EUID=0).";
      command = "printf ''";
      when = ''[ "$(id -u)" = "0" ]'';
      shell = customShell;
      format = pill {
        bg = palette.red;
        fg = palette.light;
        content = " # ";
      };
    };
  };

  directoryEndCustom = lib.optionalAttrs cfg.segments.path.enable {
    directory_end = {
      description = "Close the connected directory bar outside VCS repos.";
      command = ":";
      when = noVcsWhen;
      shell = customShell;
      format =
        if cfg.palette.enable && cfg.powerline.enable then
          powerEnd pathBg
        else
          "";
    };
  };

  shellCustom = lib.optionalAttrs cfg.segments.shell.enable {
    shell_name = {
      description = "Compact current-shell chip.";
      command = ''basename "''${SHELL:-sh}"'';
      when = "true";
      shell = customShell;
      format = pill {
        bg = palette.blue;
        fg = palette.light;
        content = "  $output ";
      };
    };
  };

  jjCustom = lib.optionalAttrs cfg.segments.jj.enable {
    jj = {
      description = "Minimal Jujutsu segment rendered directly by jj.";
      command = ''d=$PWD; while [ -n "$d" ]; do if [ -e "$d/.jj" ]; then exec jj log --ignore-working-copy --no-graph -r @ -T 'separate(" ", bookmarks, change_id.shortest(4))'; fi; d=''${d%/*}; done; exit 1'';
      when = true;
      shell = customShell;
      format =
        if cfg.palette.enable && cfg.powerline.enable then
          "(${powerJoin pathBg jjBg}[ jj $output ](fg:${palette.light} bg:${jjBg})${powerEnd jjBg})"
        else
          "(${pill {
            bg = jjBg;
            fg = palette.light;
            content = " jj $output ";
          }})";
    };
  };

  gitCustom = lib.optionalAttrs cfg.segments.git.enable {
    git_branch = {
      description = "Compact Git branch and status chip, hidden inside Jujutsu repos.";
      require_repo = true;
      when = true;
      command = ''
        d=$PWD; g=; while [ -n "$d" ]; do [ -e "$d/.jj" ] && exit 1; [ -e "$d/.git" ] && g=1; d=''${d%/*}; done; [ -n "$g" ] || exit 1
        git --no-optional-locks status --porcelain=v2 --branch -uno 2>/dev/null | awk '
          /^# branch\.oid / { oid = substr($3, 1, 7) }
          /^# branch\.head / { head = $3 }
          /^# branch\.ab / { a = substr($3, 2) + 0; b = substr($4, 2) + 0 }
          /^u / { u++ }
          /^[12] / {
            c = substr($2, 1, 1); w = substr($2, 2, 1)
            if (c != ".") s++
            if (w == "D") x++
            else if (w != ".") m++
          }
          END {
            br = (head == "(detached)" || head == "") ? ((oid == "(initial)" || oid == "") ? "HEAD" : oid) : head
            st = ""
            if (u) st = st "=" u
            if (s) st = st "+" s
            if (m) st = st "!" m
            if (x) st = st "✘" x
            if (a) st = st "⇡" a
            if (b) st = st "⇣" b
            if (st != "") printf "%s %s", br, st
            else if (br != "") printf "%s", br
          }
        '
      '';
      shell = customShell;
      format =
        if cfg.palette.enable && cfg.powerline.enable then
          "(${powerJoin pathBg vcsBg}[  $output ](fg:${palette.dark} bg:${vcsBg})${powerEnd vcsBg})"
        else
          "(${pill {
            bg = vcsBg;
            fg = palette.dark;
            content = "  $output ";
          }})";
    };
  };

  customSegments = rootIndicatorCustom // directoryEndCustom // shellCustom // gitCustom // jjCustom;

  customAttrs = lib.optionalAttrs (customSegments != { }) { custom = customSegments; };

  formatString =
    "$directory"
    + (lib.optionalString cfg.segments.path.enable "\${custom.directory_end}")
    + (lib.optionalString cfg.segments.git.enable "\${custom.git_branch}")
    + (lib.optionalString cfg.segments.jj.enable "\${custom.jj}")
    + (lib.optionalString cfg.segments.shell.enable "\${custom.shell_name}")
    + (lib.optionalString cfg.segments.rootIndicator.enable "\${custom.root_indicator}")
    + "$cmd_duration"
    + "$line_break"
    + "$character";
in
{
  options.martin.prompt.starship = {
    enable = lib.mkEnableOption "Starship prompt under Nix (replaces unmanaged ~/.config/starship.toml)";

    palette.enable =
      lib.mkEnableOption "Small glassy prompt palette designed for transparent terminals";

    powerline.enable = lib.mkEnableOption "Rounded prompt chips and subtle two-line prompt guides";

    segments = {
      shell.enable = lib.mkEnableOption "Compact current-shell chip";
      rootIndicator.enable = lib.mkEnableOption "Root warning chip when EUID=0";
      path.enable = lib.mkEnableOption "Compact path chip (fish-style abbreviation)";
      git.enable = lib.mkEnableOption "Git branch/status chips, with the branch hidden inside Jujutsu repos";
      jj.enable = lib.mkEnableOption "Jujutsu chip rendered directly by jj";
      status.enable = lib.mkEnableOption "Red X-mark on non-zero exit via [character] error_symbol";
      runtimes.enable = lib.mkEnableOption "Right-prompt language runtime version chips";
      rPromptTime.enable = lib.mkEnableOption "Right-prompt tool/runtime chips and compact time";
    };
  };

  config = lib.mkIf cfg.enable {
    home.sessionVariables.STARSHIP_LOG = "error";

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;

      settings = {
        add_newline = false;
        command_timeout = 2000;
        scan_timeout = 30;
        format = formatString;
        right_format =
          (lib.optionalString cfg.segments.runtimes.enable "$nodejs$python$golang$rust")
            + "$nix_shell$time";

        cmd_duration = {
          min_time = 1000;
          show_milliseconds = false;
          format = pill {
            bg = palette.lavender;
            fg = palette.light;
            content = " 󰔚 $duration ";
          };
        };

        directory =
          if cfg.segments.path.enable then
            {
              fish_style_pwd_dir_length = 1;
              truncation_length = 3;
              truncate_to_repo = false;
              home_symbol = "~";
              read_only = " ";
              read_only_style = plainStyle palette.red;
              style = plainStyle palette.dark;
              format =
                if cfg.palette.enable && cfg.powerline.enable then
                  "${powerStart pathBg}[  $path$read_only ](fg:${palette.dark} bg:${pathBg})"
                else
                  pill {
                    bg = pathBg;
                    fg = palette.dark;
                    content = "  $path$read_only ";
                  };
            }
          else
            { disabled = true; };

        character =
          if cfg.segments.status.enable then
            {
              error_symbol = promptError;
              success_symbol = promptSuccess;
              vimcmd_symbol = promptVim;
            }
          else
            {
              error_symbol = "[❯](bold red) ";
              success_symbol = "[❯](bold green) ";
              vimcmd_symbol = "[❮](bold blue) ";
            };

        git_branch.disabled = true;
        git_status.disabled = true;

        dotnet = {
          detect_files = [
            "global.json"
            "Directory.Build.props"
            "Directory.Build.targets"
            "Packages.props"
          ];
        };

        golang =
          if cfg.segments.runtimes.enable then
            {
              symbol = " ";
              format = pill {
                bg = palette.cyan;
                fg = palette.dark;
                content = " $symbol$version ";
              };
            }
          else
            { disabled = true; };

        lua.symbol = " ";
        nix_shell = {
          symbol = " ";
          format = pill {
            bg = palette.cyan;
            fg = palette.dark;
            content = " $symbol$state ";
          };
        };

        nodejs =
          if cfg.segments.runtimes.enable then
            {
              symbol = " ";
              detect_extensions = [ ];
              detect_files = [
                "package.json"
                ".node-version"
                ".nvmrc"
                ".tool-versions"
              ];
              detect_folders = [
                "node_modules"
              ];
              format = pill {
                bg = palette.green;
                fg = palette.dark;
                content = " $symbol$version ";
              };
            }
          else
            { disabled = true; };

        python =
          if cfg.segments.runtimes.enable then
            {
              python_binary = [
                "./.venv/bin/python"
                "./.venv/bin/python3"
              ];
              symbol = " ";
              format = pill {
                bg = palette.blue;
                fg = palette.light;
                content = " $symbol($version )($virtualenv )";
              };
            }
          else
            { disabled = true; };

        rust =
          if cfg.segments.runtimes.enable then
            {
              symbol = " ";
              format = pill {
                bg = palette.orange;
                fg = palette.dark;
                content = " $symbol$version ";
              };
            }
          else
            { disabled = true; };

        package.disabled = true;
        buf.disabled = true;

        time =
          if cfg.segments.rPromptTime.enable then
            {
              disabled = false;
              time_format = "%d %H:%M";
              format = pill {
                bg = palette.cyan;
                fg = palette.light;
                content = "  $time ";
              };
              style = plainStyle palette.light;
            }
          else
            { disabled = true; };
      } // customAttrs;
    };
  };
}
