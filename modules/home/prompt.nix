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

  gitWhen = "! jj root >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1";
  noVcsWhen = "! jj root >/dev/null 2>&1 && ! git rev-parse --is-inside-work-tree >/dev/null 2>&1";

  pathBg = palette.orange;
  vcsBg = palette.yellow;
  jjBg = palette.lavender;

  powerStart = bg: "[](fg:${bg})";
  powerJoin = from: to: "[](fg:${from} bg:${to})";
  powerEnd = bg: "[](fg:${bg}) ";
  customShell = [ "sh" ];

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
      command = "printf ''";
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
      command = ''jj log --ignore-working-copy --no-graph -r @ -T 'separate(" ", bookmarks, change_id.shortest(4))' '';
      when = "jj root >/dev/null 2>&1";
      shell = customShell;
      format =
        if cfg.palette.enable && cfg.powerline.enable then
          "${powerJoin pathBg jjBg}[ jj $output ](fg:${palette.light} bg:${jjBg})${powerEnd jjBg}"
        else
          pill {
            bg = jjBg;
            fg = palette.light;
            content = " jj $output ";
          };
    };
  };

  gitCustom = lib.optionalAttrs cfg.segments.git.enable {
    git_branch = {
      description = "Compact Git branch chip, hidden inside Jujutsu repos.";
      command = ''
        git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
      '';
      when = gitWhen;
      shell = customShell;
      format =
        if cfg.palette.enable && cfg.powerline.enable then
          "${powerJoin pathBg vcsBg}[  $output ](fg:${palette.dark} bg:${vcsBg})"
        else
          pill {
            bg = vcsBg;
            fg = palette.dark;
            content = "  $output ";
          };
    };

    git_end = {
      description = "Close the connected Git bar.";
      command = "printf ''";
      when = gitWhen;
      shell = customShell;
      format =
        if cfg.palette.enable && cfg.powerline.enable then
          powerEnd vcsBg
        else
          "";
    };
  };

  customSegments = rootIndicatorCustom // directoryEndCustom // shellCustom // gitCustom // jjCustom;

  customAttrs = lib.optionalAttrs (customSegments != { }) { custom = customSegments; };

  formatString =
    "$directory"
    + (lib.optionalString cfg.segments.path.enable "\${custom.directory_end}")
    + (lib.optionalString cfg.segments.git.enable "\${custom.git_branch}$git_status\${custom.git_end}")
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
      rPromptTime.enable = lib.mkEnableOption "Right-prompt tool/runtime chips and compact time";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;

      settings = {
        add_newline = false;
        command_timeout = 2000;
        format = formatString;
        right_format = "$nodejs$python$golang$rust$nix_shell$time";

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
            };

        git_branch.disabled = true;
        git_status =
          if cfg.segments.git.enable then
            {
              style = plainStyle palette.dark;
              format =
                if cfg.palette.enable && cfg.powerline.enable then
                  "([ $all_status$ahead_behind ](fg:${palette.dark} bg:${vcsBg}))"
                else if cfg.palette.enable then
                  "([ $all_status$ahead_behind ](fg:${palette.dark} bg:${vcsBg}) )"
                else
                  "([$all_status$ahead_behind](bold) )";
              conflicted = "=\${count}";
              ahead = "⇡\${count}";
              behind = "⇣\${count}";
              diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
              up_to_date = "";
              untracked = "?\${count}";
              stashed = "\\$\${count}";
              modified = "!\${count}";
              staged = "+\${count}";
              renamed = "»\${count}";
              deleted = "✘\${count}";
            }
          else
            { disabled = true; };

        dotnet = {
          detect_files = [
            "global.json"
            "Directory.Build.props"
            "Directory.Build.targets"
            "Packages.props"
          ];
        };

        golang = {
          symbol = " ";
          format = pill {
            bg = palette.cyan;
            fg = palette.dark;
            content = " $symbol$version ";
          };
        };

        lua.symbol = " ";
        nix_shell = {
          symbol = " ";
          format = pill {
            bg = palette.cyan;
            fg = palette.dark;
            content = " $symbol$state ";
          };
        };

        nodejs = {
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
        };

        python = {
          symbol = " ";
          format = pill {
            bg = palette.blue;
            fg = palette.light;
            content = " $symbol$version$virtualenv ";
          };
        };

        rust = {
          symbol = " ";
          format = pill {
            bg = palette.orange;
            fg = palette.dark;
            content = " $symbol$version ";
          };
        };

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
