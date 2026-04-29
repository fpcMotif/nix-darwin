{ ... }:

{
  programs.kitty = {
    enable = true;
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
