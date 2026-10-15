{ pkgs, lib, darwinConfigurationInput, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };

  cfg = darwinConfigurationInput.config;
  user = cfg.system.primaryUser;
  defaults = cfg.system.defaults;
  custom = defaults.CustomUserPreferences;
  postActivation = cfg.system.activationScripts.postActivation.text;
  home = cfg.home-manager.users.${user};

  hasPackage = name: packages: lib.any (pkg: lib.getName pkg == name) packages;

  expectEach = domainLabel: actualSet: expected:
    lib.mapAttrsToList
      (key: want:
        helpers.assertTest "darwin-settings-${domainLabel}-${key}"
          (actualSet.${key} == want)
          "system.defaults.${domainLabel}.${key} should be ${builtins.toJSON want} but is ${builtins.toJSON (actualSet.${key} or null)}")
      expected;

  expectValue = label: actual: want:
    helpers.assertTest "darwin-settings-${label}"
      (actual == want)
      "${label} should be ${builtins.toJSON want} but is ${builtins.toJSON actual}";

  # Imperative pmset and Squirrel steps run only on switch, so match their
  # emitted commands in postActivation text at eval time.
  expectActivation = label: needle:
    helpers.assertTest "darwin-settings-activation-${label}"
      (lib.hasInfix needle postActivation)
      "postActivation text should contain ${builtins.toJSON needle} (${label})";

  expectedNSGlobalDomain = {
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
    AppleShowScrollBars = "WhenScrolling";
  };

  expectedFinder = {
    _FXSortFoldersFirst = true;
    AppleShowAllExtensions = false;
    AppleShowAllFiles = true;
    FXDefaultSearchScope = "SCcf";
    FXEnableExtensionChangeWarning = false;
    FXPreferredViewStyle = "clmv";
    # nix-darwin's NewWindowTarget option converts "Home" into the plist code
    # "PfHm" that macOS stores.
    NewWindowTarget = "PfHm";
    QuitMenuItem = true;
    ShowExternalHardDrivesOnDesktop = false;
    ShowHardDrivesOnDesktop = false;
    ShowMountedServersOnDesktop = false;
    ShowPathbar = true;
    ShowRemovableMediaOnDesktop = false;
    ShowStatusBar = true;
  };

  expectedDock = {
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

  expectedTrackpad = {
    Clicking = true;
    Dragging = false;
    TrackpadRightClick = true;
    TrackpadThreeFingerDrag = true;
  };

  expectedScreencapture = {
    include-date = false;
    location = "~/Pictures";
    type = "png";
  };

  expectedActivityMonitor = {
    SortColumn = "CPUUsage";
    SortDirection = 0;
  };

  expectedMenuExtraClock = {
    Show24Hour = true;
    ShowDate = 1;
  };

  expectedCustomNSGlobalDomain = {
    AppleAccentColor = 6;
    AppleScrollerPagingBehavior = true;
    AppleWindowTabbingMode = "always";
    # Pin macOS's 0.5s default because the 0.15s slider minimum splits normal
    # double-clicks into two single clicks.
    "com.apple.mouse.doubleClickThreshold" = 0.5;
  };

  expectedDesktopServices = {
    DSDontWriteNetworkStores = true;
    DSDontWriteUSBStores = true;
  };

  expectedDiskImages = {
    skip-verify = false;
    skip-verify-locked = false;
    skip-verify-remote = false;
  };

  expectedPmsetParams = [
    "displaysleep 15"
    "sleep 20"
    "disksleep 30"
    "womp 0"
    "acwake 0"
    "proximitywake 0"
    "tcpkeepalive 0"
    "powernap 0"
    "halfdim 1"
    "standby 1"
    "standbydelayhigh 7200"
    "standbydelaylow 3600"
    "hibernatemode 3"
    "pmset -b gpuswitch 2"
    "pmset -c gpuswitch 1"
  ];

  expectedFonts = [
    "sf-mono"
    "sf-symbols"
    "MapleMono-NF-CN"
    "fira-code"
    "material-symbols"
    "nerd-fonts-dejavu-sans-mono"
    "nerd-fonts-fira-code"
    "nerd-fonts-roboto-mono"
    "nerd-fonts-symbols-only"
    "noto-fonts-cjk-sans"
    "noto-fonts-color-emoji"
    "source-han-mono"
  ];

  systemDefaultsChecks =
    expectEach "NSGlobalDomain" defaults.NSGlobalDomain expectedNSGlobalDomain
    ++ expectEach "finder" defaults.finder expectedFinder
    ++ expectEach "dock" defaults.dock expectedDock
    ++ expectEach "trackpad" defaults.trackpad expectedTrackpad
    ++ expectEach "screencapture" defaults.screencapture expectedScreencapture
    ++ expectEach "ActivityMonitor" defaults.ActivityMonitor expectedActivityMonitor
    ++ expectEach "menuExtraClock" defaults.menuExtraClock expectedMenuExtraClock;

  customPreferenceChecks =
    expectEach "CustomUserPreferences.NSGlobalDomain"
      custom.NSGlobalDomain
      expectedCustomNSGlobalDomain
    ++ expectEach "CustomUserPreferences.com.apple.desktopservices"
      custom."com.apple.desktopservices"
      expectedDesktopServices
    ++ expectEach "CustomUserPreferences.com.apple.frameworks.diskimages"
      custom."com.apple.frameworks.diskimages"
      expectedDiskImages
    ++ [
      (expectValue "CustomUserPreferences-CrashReporter-DialogType"
        custom."com.apple.CrashReporter".DialogType "none")
      (expectValue "CustomUserPreferences-finder-QLEnableTextSelection"
        custom."com.apple.finder".QLEnableTextSelection
        true)
      (expectValue "CustomUserPreferences-finder-FXInfoPanesExpanded-MetaData"
        custom."com.apple.finder".FXInfoPanesExpanded.MetaData
        true)
      (expectValue "CustomUserPreferences-finder-FXInfoPanesExpanded-Preview"
        custom."com.apple.finder".FXInfoPanesExpanded.Preview
        false)
      (expectValue "CustomUserPreferences-screencapture-name"
        custom."com.apple.screencapture".name "screenshot")
    ];

  securityChecks = [
    (expectValue "security-sudo-touchid"
      cfg.security.pam.services.sudo_local.touchIdAuth
      true)
    (expectValue "security-firewall-allow-signed"
      cfg.networking.applicationFirewall.allowSigned
      true)
    (expectValue "security-firewall-allow-signed-app"
      cfg.networking.applicationFirewall.allowSignedApp
      true)

    # Lock in the spctl status guard so a refactor cannot turn Gatekeeper into
    # an unconditional toggle.
    (helpers.assertTest "darwin-settings-gatekeeper-conditional-reenable"
      (lib.hasInfix "spctl --status" postActivation
        && lib.hasInfix "grep -q 'disabled'" postActivation)
      "Gatekeeper re-enable should stay guarded behind an spctl --status | grep -q 'disabled' check")
  ];

  # skhd's CGEventTap conflicts with BetterMouse on this host, so lock in the
  # disabled state.
  hotkeyChecks = [
    (helpers.assertTest "darwin-settings-skhd-disabled"
      (cfg.martin.skhd.enable == false
        && cfg.services.skhd.enable == false)
      "skhd should stay disabled while BetterMouse owns the event tap")
  ];

  powerManagementChecks =
    map (param: expectActivation "pmset-${param}" param) expectedPmsetParams;

  fontChecks =
    [
      (expectValue "fonts-enabled" cfg.martin.fonts.enable true)
      (helpers.assertTest "darwin-settings-fonts-count"
        (builtins.length cfg.fonts.packages == builtins.length expectedFonts)
        "fonts.packages should contain exactly ${toString (builtins.length expectedFonts)} fonts but has ${toString (builtins.length cfg.fonts.packages)}")
      (expectActivation "fonts-registry-refresh" "atsutil databases -remove")
    ]
    ++ map
      (name:
        helpers.assertTest "darwin-settings-fonts-${name}"
          (hasPackage name cfg.fonts.packages)
          "fonts.packages should include ${name}")
      expectedFonts;

  rimeChecks = [
    (expectValue "rime-enabled" cfg.martin.rime.enable true)
    (expectValue "rime-manage-app-disabled" cfg.martin.rime.manageApp false)
    # Host "f" runs a patched Squirrel build from ~/devv/squirrel, so manageApp
    # stays false to prevent nix-darwin from overwriting it.
    (helpers.assertTest "darwin-settings-rime-squirrel-package"
      (!(hasPackage "squirrel" cfg.environment.systemPackages))
      "rime should not force-install the Squirrel input method package while manageApp is disabled")
    (helpers.assertTest "darwin-settings-rime-app-not-managed"
      (
        !(lib.hasInfix "/Library/Input Methods" postActivation)
        && !(lib.hasInfix "Squirrel.app" postActivation)
      )
      "rime should not touch /Library/Input Methods or Squirrel.app in postActivation while manageApp is disabled")
    (helpers.assertTest "darwin-settings-rime-user-config-sync"
      (
        let act = home.home.activation.rimeUserConfig.data;
        in lib.hasInfix "Library/Rime" act && lib.hasInfix "rsync" act
      )
      "rime should rsync the MyRime-main tree into ~/Library/Rime on activation")
  ];

  # BetterMouse and BetterDisplay self-update via Sparkle in /Applications, so
  # both stay GUI-managed outside Nix (ADR-0011, ADR-0012).
  displayChecks =
    let
      agents = home.launchd.agents;
    in
    [
      (helpers.assertTest "darwin-settings-no-betterdisplay-agent"
        (!(agents ? betterdisplay))
        "BetterDisplay should have no LaunchAgent: it is managed through its own GUI, not Nix")
      (helpers.assertTest "darwin-settings-no-bettermouse-agent"
        (!(agents ? bettermouse))
        "BetterMouse should have no LaunchAgent: it is managed through its own GUI, not Nix")
    ];

  checks =
    systemDefaultsChecks
    ++ customPreferenceChecks
    ++ securityChecks
    ++ hotkeyChecks
    ++ powerManagementChecks
    ++ fontChecks
    ++ rimeChecks
    ++ displayChecks;
in
helpers.testSuite "darwin-settings" checks
