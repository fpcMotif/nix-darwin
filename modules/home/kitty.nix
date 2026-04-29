{ pkgs, lib, ... }:

let
  sxyaziIcon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/sxyazi/dotfiles/main/kitty/kitty.app.icns";
    sha256 = "110s4gb6mkgnmh6hl1jy361kji14v9hl30g9vb48xah6zs6zzqh8";
  };

  kittyWithIcon = pkgs.kitty.overrideAttrs (old: {
    doCheck = false;
    doInstallCheck = false;
    postInstall = (old.postInstall or "") + lib.optionalString pkgs.stdenv.isDarwin ''
      cp -f ${sxyaziIcon} $out/Applications/kitty.app/Contents/Resources/kitty.icns
    '';
  });
in
{
  programs.kitty = {
    enable = true;
    package = kittyWithIcon;
    themeFile = "Catppuccin-Macchiato";

    font = {
      name = "MonoLisa";
      size = 18;
    };

    settings = {
      shell_integration = "enabled";
      cursor_blink_interval = "0.5";
      mouse_hide_wait = "3.0";

      macos_option_as_alt = "yes";
      macos_quit_when_last_window_closed = "yes";
      hide_window_decorations = "titlebar-only";
      confirm_os_window_close = 0;

      window_padding_width = 0;
      background_opacity = "1.0";
      mouse_wheel_scroll_multiplier = "0.4";

      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";

      enable_audio_bell = "no";
      visual_bell_duration = "0.0";
    };
  };
}
