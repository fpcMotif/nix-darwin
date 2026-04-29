{ config, lib, pkgs, ... }:

let
  cfg = config.martin.prompt.starship;
  vcsEnable = cfg.segments.jj.enable || cfg.segments.git.enable;
  jjStarshipBin = lib.getExe cfg.segments.jj.package;
  jjStarshipShell = [
    jjStarshipBin
    "--no-color"
    "--jj-symbol"
    "󱗆 "
    "--git-symbol"
    "${gitIcon} "
    "--no-git-id"
    "--no-git-status"
  ];
  vcsWhen =
    if cfg.segments.jj.enable && cfg.segments.git.enable then
      "${jjStarshipBin} detect"
    else if cfg.segments.jj.enable then
      "jj root >/dev/null 2>&1"
    else
      "! jj root >/dev/null 2>&1 && ${jjStarshipBin} detect";

  palette = {
    grey = "#454758";
    lavender = "#AE8FE7";
    white = "#FFFFFF";
    text = "#494D64";
    yellow = "#FFEE58";
    red = "#ff8080";
  };

  pwSep = "";
  xMark = "";
  bolt = "⚡";
  gitIcon = "";

  pathStyle =
    if cfg.palette.enable then "fg:${palette.white} bg:${palette.grey}" else "bold";
  pathTrail =
    if cfg.powerline.enable && cfg.palette.enable then
      "[${pwSep}](fg:${palette.grey})"
    else
      "";

  vcsStyle =
    if cfg.palette.enable then "fg:${palette.text} bg:${palette.lavender}" else "bold";
  vcsTrail =
    if cfg.powerline.enable && cfg.palette.enable then
      "[${pwSep}](fg:${palette.lavender})"
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

  jjCustom = lib.optionalAttrs vcsEnable {
    jj = {
      description = "Powerline VCS segment rendered by jj-starship.";
      when = vcsWhen;
      format = "[ $output ](${vcsStyle})${vcsTrail}";
      shell = jjStarshipShell;
    };
  };

  customSegments = rootIndicatorCustom // jjCustom;

  customAttrs = lib.optionalAttrs (customSegments != { }) { custom = customSegments; };

  formatString =
    (lib.optionalString cfg.segments.rootIndicator.enable "\${custom.root_indicator}")
    + "$directory"
    + (lib.optionalString vcsEnable "\${custom.jj}")
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
      git.enable = lib.mkEnableOption "Git support in the unified jj-starship powerline segment";
      jj = {
        enable = lib.mkEnableOption "Jujutsu support in the unified jj-starship powerline segment";
        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.jj-starship;
          defaultText = lib.literalExpression "pkgs.jj-starship";
          description = "jj-starship package used by the Git and Jujutsu Starship custom segments.";
        };
      };
      status.enable = lib.mkEnableOption "Red X-mark on non-zero exit via [character] error_symbol";
      rPromptTime.enable = lib.mkEnableOption "Right-prompt time in lavender (zsh; bash needs ble.sh)";
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
        right_format = "$time";

        git_branch.disabled = true;
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
