{ lib, pkgs, ... }:

{
  nix.configureBuildUsers = true;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  time.timeZone = lib.mkDefault "Australia/Perth";

  system = {
    defaults = {
      NSGlobalDomain = {
        # UX defaults
        AppleShowAllExtensions = true;
        AppleKeyboardUIMode = 3;
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 10;
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;

        # Keep the menu bar visible by default.
        _HIHideMenuBar = false;

        # Trackpad and keyboard defaults.
        "com.apple.swipescrolldirection" = false;
        NSWindowResizeTime = 0.001;
      };

      dock = {
        autohide = true;
        orientation = "left";
        showhidden = true;
        show-process-indicators = false;
        show-recents = false;
        tilesize = 48;
      };

      finder = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "clmv";
        ShowPathbar = true;
        QuitMenuItem = true;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };

      ActivityMonitor = {
        SortColumn = "CPUUsage";
        SortDirection = 0;
      };

      LaunchServices = {
        LSQuarantine = false;
      };

      CustomSystemPreferences = {
        NSGlobalDomain = {
          AppleAccentColor = 6;
          AppleScrollerPagingBehavior = true;
          AppleWindowTabbingMode = "always";
        };

        "com.apple.finder" = {
          ShowExternalHardDrivesOnDesktop = false;
          ShowHardDrivesOnDesktop = false;
          ShowMountedServersOnDesktop = false;
          ShowRemovableMediaOnDesktop = false;
          _FXSortFoldersFirst = true;
          NewWindowTarget = "PfHm";
          NewWindowTargetPath = "file://$HOME/";
          QLEnableTextSelection = true;
        };

        "com.apple.screencapture" = {
          include-date = false;
          location = "~/Pictures";
          type = "png";
        };

        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };

        "com.apple.frameworks.diskimages" = {
          skip-verify = true;
          skip-verify-locked = true;
          skip-verify-remote = true;
        };

        "com.apple.CrashReporter" = {
          DialogType = "none";
        };

        "com.apple.AdLib" = {
          forceLimitAdTracking = true;
          allowApplePersonalizedAdvertising = false;
          allowIdentifierForAdvertising = false;
        };
      };
    };
  };
}
