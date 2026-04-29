{ lib, pkgs, ... }:

let
  hasPackage = name: builtins.hasAttr name pkgs;
in
{
  home.activation.checkNixManagedGhostty = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -e "$HOME/.config/ghostty/config" ] && ! [ -L "$HOME/.config/ghostty/config" ]; then
      echo "ERROR: ~/.config/ghostty/config is still unmanaged." >&2
      echo "Please archive/remove it so Home Manager can manage Ghostty settings." >&2
      exit 1
    fi
  '';

  home.packages =
    lib.optionals (pkgs.stdenv.isDarwin && hasPackage "ghostty-bin") [
      pkgs.ghostty-bin
    ]
    ++ lib.optionals (!pkgs.stdenv.isDarwin && hasPackage "ghostty") [
      pkgs.ghostty.terminfo
    ];

  xdg.configFile."ghostty/config".text = ''
    theme = Catppuccin Macchiato

    shell-integration = zsh
    quit-after-last-window-closed = true

    font-family = MonoLisa
    font-style = Regular
    font-style-italic = Regular Italic
    font-style-bold = Bold
    font-style-bold-italic = Bold Italic
    font-size = 18

    unfocused-split-opacity = 0.97
    background-opacity = 1.0
    cursor-style-blink = true

    clipboard-read = allow
    clipboard-write = allow

    macos-option-as-alt = true
    macos-titlebar-proxy-icon = hidden
    title = ghostty

    window-width = 90
    window-height = 30
    window-colorspace = display-p3
    window-padding-color = background
    window-padding-balance = true
    window-padding-x = 0
    window-padding-y = 0

    mouse-scroll-multiplier = 0.4
  '';
}
