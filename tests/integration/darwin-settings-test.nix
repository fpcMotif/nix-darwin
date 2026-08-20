# Integration test: locks in the exact macOS settings host "f" commits to.
#
# Tier 1 (pure-eval, hermetic) of the macOS-settings test strategy documented in
# docs/adr/0004-macos-settings-testing-strategy.md. Every declarative
# `system.defaults` key is asserted against its exact expected value, so an
# accidental edit -- or an automated commit -- that flips a setting fails
# `nix flake check` loudly. The `expected*` attrsets below ARE the spec: they
# read as the table of macOS state this configuration promises.
#
# The imperative activation layer (pmset power management, the Squirrel input
# method symlink) cannot be checked for *effect* without a real darwin-rebuild,
# so it is asserted here by string-matching the rendered postActivation text --
# the most eval can see. Live read-back of the activated machine is the opt-in
# Tier 2 script scripts/verify-macos-settings.sh.
#
# Darwin-only: macOS settings do not exist on the NixOS hosts, so on non-darwin
# builders tests/default.nix wires this in as a no-op skip.
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

  # One assertTest per (key -> expected value). `actualSet.${key}` resolves the
  # live option value, so a drifted key fails with a precise before/after message.
  # The `expected*` attrset passed in is the human-readable spec for that domain.
  expectEach = domainLabel: actualSet: expected:
    lib.mapAttrsToList
      (key: want:
        helpers.assertTest "darwin-settings-${domainLabel}-${key}"
          (actualSet.${key} == want)
          "system.defaults.${domainLabel}.${key} should be ${builtins.toJSON want} but is ${builtins.toJSON (actualSet.${key} or null)}")
      expected;

  # Single exact-value assertion against an arbitrary live value.
  expectValue = label: actual: want:
    helpers.assertTest "darwin-settings-${label}"
      (actual == want)
      "${label} should be ${builtins.toJSON want} but is ${builtins.toJSON actual}";

  # String-match assertion over the rendered activation script. The imperative
  # pmset/Squirrel logic only runs on a real switch; this is the eval-visible
  # proxy that the intended command was emitted.
  expectActivation = label: needle:
    helpers.assertTest "darwin-settings-activation-${label}"
      (lib.hasInfix needle postActivation)
      "postActivation text should contain ${builtins.toJSON needle} (${label})";

  # ---- system.defaults: native option domains -----------------------------

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
    # nix-darwin's NewWindowTarget option `apply`s the friendly "Home" (set in
    # modules/darwin/defaults.nix) to the plist code macOS actually stores.
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

  # ---- system.defaults.CustomUserPreferences: freeform domains ------------

  expectedCustomNSGlobalDomain = {
    AppleAccentColor = 6;
    AppleScrollerPagingBehavior = true;
    AppleWindowTabbingMode = "always";
    # macOS ships 0.5s. The System Settings slider bottoms out at 0.15s, where a
    # double-click must land inside 150ms or the OS delivers two single clicks.
    # Pinned after the machine was found sitting at the fast extreme by hand.
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

  # ---- pmset power-management (imperative, eval-visible via activation text)

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

  # ---- fonts (membership of the curated bundle) ---------------------------

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

  # =========================================================================

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

    # Gatekeeper is re-enabled CONDITIONALLY -- only when spctl reports it is
    # currently disabled. Lock in the guard so a refactor cannot turn this into
    # an unconditional toggle (the eval-test covers --master-enable presence).
    (helpers.assertTest "darwin-settings-gatekeeper-conditional-reenable"
      (lib.hasInfix "spctl --status" postActivation
        && lib.hasInfix "grep -q 'disabled'" postActivation)
      "Gatekeeper re-enable should stay guarded behind an spctl --status | grep -q 'disabled' check")
  ];

  # skhd global hotkeys, retired 2026-07-19. skhd's CGEventTap conflicts with
  # BetterMouse's, so the daemon is off and nix-darwin renders no launchd agent,
  # no package, and no config text -- the launcher-prefix, display-sleep, reload,
  # Raycast, and Ghostty-split assertions that lived here had nothing left to
  # match. What is worth locking in now is the OFF state itself: this host runs
  # BetterMouse, and a silent re-enable would bring the tap conflict back.
  # HOTKEYS.md carries the user-facing consequences.
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
    # Host "f" runs a manually-built, patched Squirrel fork (~/devv/squirrel),
    # so martin.rime.manageApp = false keeps nix-darwin from installing the
    # vanilla pkgs.martin.squirrel build over it. That drops squirrel from
    # systemPackages and skips the whole copy-into-/Library/Input-Methods
    # block in postActivation -- both asserted absent below, not present.
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

  # Neither BetterMouse nor BetterDisplay is Nix-managed any more: both ship
  # Sparkle, which self-updates the writable /Applications copy out from under
  # the pin. These guards keep the scaffolding from being re-added by reflex.
  # See docs/adr/0011-bettermouse-is-gui-managed-not-nix-managed.md and
  # docs/adr/0012-betterdisplay-is-gui-managed-not-nix-managed.md.
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
