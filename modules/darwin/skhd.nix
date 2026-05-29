{ config, lib, pkgs, ... }:

let
  cfg = config.martin.skhd;

  # Global launcher prefix. This keeps Command free for app-native shortcuts
  # while still being uncommon enough to avoid the active Ghostty, Tmux, Rime,
  # Raycast, and macOS shortcut configs.
  prefix = "ctrl + alt + shift";

  skhd = "${pkgs.skhd}/bin/skhd";
  openApp = name: ''open -a "${name}"'';

  defaultConfig = ''
    # Global hotkeys managed by nix-darwin.
    # Prefix: ${prefix}
    #
    # Design:
    # - global app/automation shortcuts live here;
    # - app-local shortcuts stay in their own app configs;
    # - no bindings use ctrl+space or ctrl+alt+space, which macOS/Rime use for
    #   input-source behavior.

    # Finder cut/paste for files.
    #
    # Finder's native move is cmd+c followed by cmd+alt+v. This gives Finder a
    # Windows-style cmd+x/cmd+v flow without reimplementing file moves.
    :: finder_cut
    f19 ; finder_cut
    finder_cut < f19 ; default
    finder_cut < escape ; default

    cmd - x [
      "finder" : ${skhd} -k "cmd - c"; ${skhd} -k "f19"
      * ~
    ]

    finder_cut < cmd - v [
      "finder" : ${skhd} -k "cmd + alt - v"; ${skhd} -k "f19"
      * : ${skhd} -k "f19"; ${skhd} -k "cmd - v"
    ]

    finder_cut < cmd - c [
      * : ${skhd} -k "f19"; ${skhd} -k "cmd - c"
    ]

    finder_cut < cmd - x [
      "finder" : ${skhd} -k "cmd - c"
      * : ${skhd} -k "f19"; ${skhd} -k "cmd - x"
    ]

    # Launchers
    ${prefix} - return : ${openApp "Ghostty"}
    ${prefix} - space  : ${openApp "Raycast"}
    ${prefix} - a      : ${openApp "Claude"}
    ${prefix} - c      : ${openApp "Cursor"}
    ${prefix} - d      : ${openApp "Drafts"}
    ${prefix} - f      : ${openApp "Finder"}
    ${prefix} - s      : ${openApp "Safari"}
    ${prefix} - t      : ${openApp "Terminal"}
    ${prefix} - w      : ${openApp "Warp"}

    # Workflows
    ${prefix} - n      : open -a "Cursor" "$HOME/nix-config"
    ${prefix} - h      : open "$HOME/nix-config/HOTKEYS.md"

    # Utilities
    ${prefix} - l      : pmset displaysleepnow
    ${prefix} - r      : ${skhd} --reload
  '';
in
{
  options.martin.skhd = {
    enable = lib.mkEnableOption "skhd hotkey daemon with a ctrl+alt+shift-prefixed launcher set";

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Additional skhd config lines appended after the defaults. Use the same
        skhd syntax (`mod1 + mod2 - key : command`).
      '';
      example = ''
        ctrl + alt + shift - t : open -a "Things3"
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.skhd ];

    services.skhd = {
      enable = true;
      package = pkgs.skhd;
      skhdConfig = defaultConfig + cfg.extraConfig;
    };
  };
}
