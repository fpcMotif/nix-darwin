{ pkgs, currentSystemUser, currentSystemUserHome, ... }:

{
  users.users.${currentSystemUser}.home = currentSystemUserHome;

  system = {
    primaryUser = currentSystemUser;
    stateVersion = 5;
  };

  environment.systemPackages = [
    pkgs.duti
    pkgs.martin.google-drive
    pkgs.martin.raycast
  ];

  martin = {
    backgroundServices = {
      cleanMyMacManualOnly = true;

      dropbox = {
        installClient = false;
        disableBackgroundUpdaters = true;
      };
    };

    fonts.enable = true;
    hammerspoon.enable = true;
    healthCheck.enable = true;

    mouseDisplay = {
      enable = true;
      bettermouse.profile = "${currentSystemUserHome}/MyRime-main/better_mouse_setting_bm_cfg_4958.plist";
    };

    rime = {
      enable = true;
      config = "${currentSystemUserHome}/MyRime-main";
    };

    spotlight.enable = true;

    skhd = {
      enable = true;
      # Add personal bindings here. skhd syntax: `mod - key : command`.
      # Global prefix `ctrl + alt + shift` is reserved by the defaults.
      extraConfig = ''
        # Ghostty split controls.
        #
        # These synthesize Ghostty's own keybinds instead of introducing a
        # macOS window-manager daemon. Outside Ghostty they only focus Ghostty,
        # so the split commands cannot become stray browser/editor shortcuts.
        ctrl + alt + shift - e [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd - d"
          * : open -a "Ghostty"
        ]

        ctrl + alt + shift - x [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd + shift - d"
          * : open -a "Ghostty"
        ]

        ctrl + alt + shift - z [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd + shift - f"
          * : open -a "Ghostty"
        ]

        ctrl + alt + shift - 0 [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd + shift - 0"
          * : open -a "Ghostty"
        ]

        ctrl + alt + shift - left [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd + alt - left"
          * : open -a "Ghostty"
        ]

        ctrl + alt + shift - right [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd + alt - right"
          * : open -a "Ghostty"
        ]

        ctrl + alt + shift - up [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd + alt - up"
          * : open -a "Ghostty"
        ]

        ctrl + alt + shift - down [
          "ghostty" : ${pkgs.skhd}/bin/skhd -k "cmd + alt - down"
          * : open -a "Ghostty"
        ]
      '';
    };
  };

  home-manager.users.${currentSystemUser}.martin = {
    prompt.starship = {
      enable = true;
      palette.enable = true;
      powerline.enable = true;

      segments = {
        shell.enable = false;
        rootIndicator.enable = false;
        path.enable = true;
        git.enable = true;
        jj.enable = true;
        status.enable = true;
        rPromptTime.enable = true;
      };
    };

    terminal.ghostty = {
      enable = true;

      theme = {
        auto = false;
        fixed = "rose-pine-moon";
        boldIsBright = false;
        customThemes."rose-pine-moon" =
          builtins.readFile ../../modules/home/ghostty-themes/rose-pine-moon;
      };

      transparency = {
        opacity = 0.0;
        blur = "macos-glass-clear";
      };

      font = {
        family = "Maple Mono NF CN";
        size = 14;
        thicken = true;
        adjustCellHeight = "15%";
      };

      cursor = {
        style = "block";
        blink = false;
        hideMouseWhileTyping = true;
      };

      window = {
        titlebarStyle = "transparent";
        saveState = "always";
        confirmClose = false;
        minimumContrast = 1.08;
        padding = {
          x = 4;
          y = 4;
          balance = true;
        };
      };

      clipboard.enable = true;
      scrollback.lines = 500000;

      shellIntegration = {
        shell = "zsh";
        features = [ "cursor" "sudo" "title" ];
      };

      quickTerminal = {
        enable = true;
        position = "top";
        animationDuration = 0.15;
      };

      splits.enable = true;
      tabs.enable = true;
    };
  };
}
