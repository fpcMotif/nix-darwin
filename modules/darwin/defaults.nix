{ lib, ... }:

# CustomUserPreferences covers what native options lack, so no `defaults
# write` scripts. Source: https://sxyz.blog/macos-setup/
{
  system.defaults = {
    NSGlobalDomain = {
      _HIHideMenuBar = true;
      AppleKeyboardUIMode = 3;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      NSWindowResizeTime = 1.0e-3;
      ApplePressAndHoldEnabled = false;
      NSDocumentSaveNewDocumentsToCloud = false;
      KeyRepeat = 1;
      InitialKeyRepeat = 10;
      "com.apple.swipescrolldirection" = false;
      # Prefer overlay scrollbars: slim while scrolling, hidden at rest.
      AppleShowScrollBars = "WhenScrolling";
    };

    CustomUserPreferences = {
      NSGlobalDomain = {
        AppleAccentColor = 6;
        AppleScrollerPagingBehavior = true;
        AppleWindowTabbingMode = "always";
        # Double-click window in seconds (macOS default 0.5); the 0.15 slider
        # minimum splits slow double-clicks into two single clicks.
        "com.apple.mouse.doubleClickThreshold" = 0.5;
      };

      "com.apple.CrashReporter" = {
        DialogType = "none";
      };

      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };

      "com.apple.finder" = {
        FXInfoPanesExpanded = {
          MetaData = true;
          Preview = false;
        };
        QLEnableTextSelection = true;
      };

      "com.apple.frameworks.diskimages" = {
        skip-verify = false;
        skip-verify-locked = false;
        skip-verify-remote = false;
      };

      # Safari prefs are sandboxed; writing them without Full Disk Access halts
      # activation. Set them by hand in Safari → Settings.

      "com.apple.screencapture" = {
        name = "screenshot";
      };

      # universalaccess and AdLib are TCC-protected; writing them halts
      # activation. Set them by hand in System Settings.
    };

    finder = {
      _FXSortFoldersFirst = true;
      # Hide extensions globally — keeps .app from rendering as "Safari.app"
      # in Finder/Spotlight/Raycast. macOS still picks the right opener.
      AppleShowAllExtensions = false;
      AppleShowAllFiles = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "clmv";
      NewWindowTarget = "Home";
      QuitMenuItem = true;
      ShowExternalHardDrivesOnDesktop = false;
      ShowHardDrivesOnDesktop = false;
      ShowMountedServersOnDesktop = false;
      ShowPathbar = true;
      ShowRemovableMediaOnDesktop = false;
      ShowStatusBar = true;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      magnification = true;
      largesize = 80;
      mru-spaces = false;
      orientation = "left";
      persistent-apps = [ ];
      show-process-indicators = false;
      show-recents = false;
      showhidden = true;
      tilesize = 48;
    };

    trackpad = {
      Clicking = true;
      Dragging = false;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    screencapture = {
      include-date = false;
      location = "~/Pictures";
      type = "png";
    };

    ActivityMonitor = {
      SortColumn = "CPUUsage";
      SortDirection = 0;
    };

    menuExtraClock = {
      Show24Hour = true;
      ShowDate = 1;
    };
  };

  # nix-darwin runs only fixed activation script names; others silently never
  # run. Custom steps go in `postActivation` with `mkAfter` so modules can append.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # pmset accepts multiple key/value pairs per invocation, so one fork
    # covers all -a settings; -b (battery) and -c (charger) keep their own.
    /usr/bin/pmset -a \
      displaysleep 15 \
      sleep 20 \
      disksleep 30 \
      womp 0 \
      acwake 0 \
      proximitywake 0 \
      tcpkeepalive 0 \
      powernap 0 \
      halfdim 1 \
      standby 1 \
      standbydelayhigh 7200 \
      standbydelaylow 3600 \
      hibernatemode 3 || true
    /usr/bin/pmset -b gpuswitch 2 || true
    /usr/bin/pmset -c gpuswitch 1 || true

    # nix-darwin's own activation restarts Finder/Dock/SystemUIServer when its
    # managed `system.defaults` change, so we don't kill them here.
  '';
}
