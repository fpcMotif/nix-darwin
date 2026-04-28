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
  };

  pwSep = "";
  xMark = "";
  bolt = "";
  gitIcon = "";

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

  rootIndicatorAttrs = lib.optionalAttrs cfg.segments.rootIndicator.enable {
    custom.root_indicator = {
      description = "Lightning bolt when running as root (EUID=0).";
      when = ''[ "$(id -u)" = "0" ]'';
      format = "[ ${bolt} ](${rootStyle})";
      shell = [
        "sh"
        "-c"
      ];
    };
  };
in
{
  options.martin.prompt.starship = {
    enable = lib.mkEnableOption "Starship prompt under Nix (replaces chezmoi-owned starship.toml)";

    palette.enable =
      lib.mkEnableOption "Mitchell-style lavender/grey/white/text/yellow/red palette";

    powerline.enable = lib.mkEnableOption "Powerline U+E0B0 chevron separators between segments";

    segments = {
      rootIndicator.enable = lib.mkEnableOption "Yellow lightning-bolt when EUID=0";
      path.enable = lib.mkEnableOption "Powerline path block (fish-style abbreviation)";
      git.enable = lib.mkEnableOption "Lavender git_branch block; git_status disabled to match omp fetch_status:false";
      status.enable = lib.mkEnableOption "Red X-mark on non-zero exit via [character] error_symbol";
      rPromptTime.enable = lib.mkEnableOption "Right-prompt time in lavender (zsh; bash needs ble.sh)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.activation.checkChezmoiStarship = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      if [ -e "$HOME/.config/starship.toml" ] && ! [ -L "$HOME/.config/starship.toml" ]; then
        echo "ERROR: chezmoi still owns ~/.config/starship.toml. To migrate:" >&2
        echo "  chezmoi forget --force ~/.config/starship.toml" >&2
        echo "  rm ~/.config/starship.toml" >&2
        echo "Then re-run darwin-rebuild." >&2
        exit 1
      fi
    '';

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;

      settings = {
        add_newline = false;
        command_timeout = 1000;
        format = "$custom$directory$git_branch$character";
        right_format = "$time";

        git_status.disabled = true;

        directory =
          if cfg.segments.path.enable then
            {
              fish_style_pwd_dir_length = 1;
              truncation_length = 3;
              truncate_to_repo = true;
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
            { };

        time =
          if cfg.segments.rPromptTime.enable then
            {
              disabled = false;
              time_format = "%a %b %e %H:%M:%S %Z";
              style = timeStyle;
            }
          else
            { };
      } // rootIndicatorAttrs;
    };
  };
}
