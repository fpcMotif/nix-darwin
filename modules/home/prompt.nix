{ config, lib, ... }:

let
  cfg = config.martin.prompt.starship;

  palette = {
    grey = "#454758";
    lavender = "#AE8FE7";
    white = "#FFFFFF";
    text = "#494D64";
    yellow = "#FFEE58";
    red = "#ff8080";
    teal = "#80E7C9";
  };

  pwSep = "";
  xMark = "";
  bolt = "⚡";
  gitIcon = "";
  jjIcon = "";

  pathStyle =
    if cfg.palette.enable then "fg:${palette.white} bg:${palette.grey}" else "bold";
  pathTrail =
    if cfg.powerline.enable && cfg.palette.enable then
      "[${pwSep}](fg:${palette.grey})"
    else
      "";

  gitStyle =
    if cfg.palette.enable then "fg:${palette.text} bg:${palette.lavender}" else "bold";
  gitTrail =
    if cfg.powerline.enable && cfg.palette.enable then
      "[${pwSep}](fg:${palette.lavender})"
    else
      "";

  jjStyle =
    if cfg.palette.enable then "fg:${palette.text} bg:${palette.teal}" else "bold";
  jjTrail =
    if cfg.powerline.enable && cfg.palette.enable then
      "[${pwSep}](fg:${palette.teal})"
    else
      "";

  rootStyle = if cfg.palette.enable then "fg:${palette.yellow}" else "bold yellow";

  statusFg = if cfg.palette.enable then "fg:${palette.white}" else "fg:white";
  statusBg = if cfg.palette.enable then "bg:${palette.red}" else "bg:red";
  statusTrail =
    if cfg.powerline.enable && cfg.palette.enable then
      "[${pwSep}](fg:${palette.red})"
    else
      "";
  statusErrorSymbol = "[ ${xMark} ](${statusFg} ${statusBg})${statusTrail}";

  timeStyle = if cfg.palette.enable then "fg:${palette.lavender}" else "bold";

  rootIndicatorCustom = lib.optionalAttrs cfg.segments.rootIndicator.enable {
    root_indicator = {
      description = "Lightning bolt when running as root (EUID=0).";
      when = ''[ "$(id -u)" = "0" ]'';
      format = "[ ${bolt} ](${rootStyle})";
      shell = [
        "sh"
        "-c"
      ];
    };
  };

  jjCustom = lib.optionalAttrs cfg.segments.jj.enable {
    jj = {
      description = "Jujutsu change-id (and bookmarks if any) inside a jj repo.";
      when = "jj root";
      command = "jj --ignore-working-copy log -r @ -n 1 --no-graph --no-pager --color=never -T 'change_id.shortest(8) ++ if(bookmarks, \" \" ++ bookmarks.map(|b| b.name()).join(\",\"), \"\")' 2>/dev/null";
      format = "[ ${jjIcon} $output ](${jjStyle})${jjTrail}";
      shell = [
        "sh"
        "-c"
      ];
    };
  };

  customSegments = rootIndicatorCustom // jjCustom;

  customAttrs = lib.optionalAttrs (customSegments != { }) { custom = customSegments; };

  formatString =
    (lib.optionalString cfg.segments.rootIndicator.enable "$custom.root_indicator")
    + "$directory"
    + (lib.optionalString cfg.segments.jj.enable "$custom.jj")
    + "$git_branch"
    + "$character";
in
{
  options.martin.prompt.starship = {
    enable = lib.mkEnableOption "Starship prompt under Nix (replaces unmanaged ~/.config/starship.toml)";

    palette.enable =
      lib.mkEnableOption "Mitchell-style lavender/grey/white/text/yellow/red palette";

    powerline.enable = lib.mkEnableOption "Powerline U+E0B0 chevron separators between segments";

    segments = {
      rootIndicator.enable = lib.mkEnableOption "Yellow lightning-bolt when EUID=0";
      path.enable = lib.mkEnableOption "Powerline path block (fish-style abbreviation)";
      git.enable = lib.mkEnableOption "Lavender git_branch block; git_status disabled to match omp fetch_status:false";
      jj.enable = lib.mkEnableOption "Teal jj block (change-id + bookmarks) inside a jj repo via 'jj log' custom segment";
      status.enable = lib.mkEnableOption "Red X-mark on non-zero exit via [character] error_symbol";
      rPromptTime.enable = lib.mkEnableOption "Right-prompt time in lavender (zsh; bash needs ble.sh)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.checkNixManagedStarship = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ -e "$HOME/.config/starship.toml" ] && ! [ -L "$HOME/.config/starship.toml" ]; then
        echo "ERROR: ~/.config/starship.toml is still unmanaged." >&2
        echo "Please archive/remove it so Home Manager can manage Starship settings." >&2
        exit 1
      fi
    '';

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;

      settings = {
        add_newline = false;
        command_timeout = 2000;
        format = formatString;
        right_format = "$time";

        git_status.disabled = true;

        directory =
          if cfg.segments.path.enable then
            {
              fish_style_pwd_dir_length = 1;
              truncation_length = 3;
              truncate_to_repo = false;
              style = pathStyle;
              format = "[ $path ]($style)${pathTrail}";
            }
          else
            { disabled = true; };

        git_branch =
          if cfg.segments.git.enable then
            {
              symbol = "${gitIcon} ";
              style = gitStyle;
              format = "[ $symbol$branch ]($style)${gitTrail}";
              truncation_length = 18;
            }
          else
            { disabled = true; };

        character =
          if cfg.segments.status.enable then
            {
              error_symbol = statusErrorSymbol;
              success_symbol = "";
            }
          else
            {
              error_symbol = "[󰘧](bold red)";
              success_symbol = "[󰘧](bold green)";
            };

        dotnet = {
          detect_files = [
            "global.json"
            "Directory.Build.props"
            "Directory.Build.targets"
            "Packages.props"
          ];
        };

        golang.symbol = " ";
        lua.symbol = " ";
        nix_shell.symbol = " ";

        nodejs = {
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
        };

        package.disabled = true;
        buf.disabled = true;

        time =
          if cfg.segments.rPromptTime.enable then
            {
              disabled = false;
              time_format = "%a %b %e %H:%M:%S %Z";
              style = timeStyle;
            }
          else
            { disabled = true; };
      } // customAttrs;
    };
  };
}
