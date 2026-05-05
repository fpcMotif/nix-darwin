{ lib, ... }:

# macOS preferences declared via nix-darwin's `system.defaults`. Native options
# are used wherever they exist; everything else falls through to
# `CustomUserPreferences` so a single `darwin-rebuild switch` is enough — no
# follow-up `defaults write` shell scripts.
#
# Notes:
#   - No Colemak / keyboard-layout swaps. Layouts are user-installed via
#     System Settings → Keyboard → Input Sources.
#   - No Homebrew. All apps come from Nix.
#   - Fonts live in ./fonts.nix. Squirrel/Rime lives in ./rime.nix.
#   - Source: https://sxyz.blog/macos-setup/
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
        skip-verify = true;
        skip-verify-locked = true;
        skip-verify-remote = true;
      };

      # Safari prefs live inside a sandboxed container; `defaults write
      # com.apple.Safari …` fails from any terminal that lacks Full Disk Access,
      # which halts the whole activation. Configure these manually in
      # Safari → Settings → Advanced/Privacy if needed.

      "com.apple.screencapture" = {
        name = "screenshot";
      };

      # com.apple.universalaccess (cursor size) and com.apple.AdLib (ad tracking)
      # are TCC-protected on modern macOS — `defaults write` fails from terminals
      # without Full Disk Access and halts activation. Adjust those in
      # System Settings → Accessibility / Privacy & Security if needed.
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

    LaunchServices = {
      LSQuarantine = false;
    };

    menuExtraClock = {
      Show24Hour = true;
      ShowDate = 1;
    };
  };

  # nix-darwin only runs a fixed set of activation script names (preActivation,
  # extraActivation, postActivation, defaults, userDefaults, …). Any other key
  # under `system.activationScripts.<name>.text` evaluates fine but is *never*
  # executed. Everything custom goes into `postActivation` with `mkAfter` so
  # other modules can append their own block without clobbering ours.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Allow opening apps from any source (Gatekeeper). Skip when already
    # disabled so we don't fork spctl every switch. macOS 15+ may ignore this
    # flag entirely; the GUI toggle in Privacy & Security is the fallback.
    if ! /usr/sbin/spctl --status 2>/dev/null | grep -q 'disabled'; then
      /usr/sbin/spctl --master-disable || true
    fi

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
