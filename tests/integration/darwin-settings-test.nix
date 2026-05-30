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
  inherit (helpers) hasPackage;

  cfg = darwinConfigurationInput.config;
  user = cfg.system.primaryUser;
  defaults = cfg.system.defaults;
  custom = defaults.CustomUserPreferences;
  postActivation = cfg.system.activationScripts.postActivation.text;
  home = cfg.home-manager.users.${user};
  skhdConfig = cfg.services.skhd.skhdConfig;

  # One assertTest per (key -> expected value), PLUS one closure guard asserting
  # the config manages EXACTLY the expected key set for the domain. The per-key
  # check reads `actualSet.${key} or null`, so a removed/renamed key fails as a
  # clean `is null` case instead of aborting the whole eval; the closure guard
  # catches the opposite drift -- a key ADDED to modules/darwin/defaults.nix but
  # not mirrored here. Native option submodules pad unmanaged keys with null, so
  # we compare against only the keys the config actually sets.
  # Nix-darwin keeps deprecated alias keys (e.g.
  # `expose-group-by-app`) in `system.defaults.*` option sets; remove known
  # deprecated aliases before strict key-set comparison to avoid false positives and
  # deprecation traces while still preserving behavior checks on canonical keys.
  deprecatedDefaultsAliases = [ "expose-group-by-app" ];

  sanitizeDefaults = attrs: builtins.removeAttrs attrs deprecatedDefaultsAliases;

  expectEach = domainLabel: actualSet: expected:
    let
      cleanSet = sanitizeDefaults actualSet;
      managedKeys = builtins.attrNames (lib.filterAttrs (_: v: v != null) cleanSet);
      expectedKeys = builtins.attrNames expected;
    in
    lib.mapAttrsToList
      (key: want:
        let got = cleanSet.${key} or null; in
        helpers.assertTest "darwin-settings-${domainLabel}-${key}"
          (got == want)
          "system.defaults.${domainLabel}.${key} should be ${builtins.toJSON want} but is ${builtins.toJSON got}")
      expected
    ++ [
      (helpers.assertTest "darwin-settings-${domainLabel}-keyset"
        (managedKeys == expectedKeys)
        "system.defaults.${domainLabel} manages ${builtins.toJSON managedKeys} but the spec expects ${builtins.toJSON expectedKeys} -- a setting was added or removed without updating this table")
    ];

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

  # Gatekeeper/quarantine: keep downloads tagged so Gatekeeper assesses them.
  expectedLaunchServices = {
    LSQuarantine = true;
  };

  # ---- system.defaults.CustomUserPreferences: freeform domains ------------

  expectedCustomNSGlobalDomain = {
    AppleAccentColor = 6;
    AppleScrollerPagingBehavior = true;
    AppleWindowTabbingMode = "always";
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

  # Key/value params carried on the single `pmset -a` line.
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
  ];

  # Separate full pmset commands (per-power-source GPU switching policy).
  expectedPmsetCommands = [
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
    ++ expectEach "menuExtraClock" defaults.menuExtraClock expectedMenuExtraClock
    ++ expectEach "LaunchServices" defaults.LaunchServices expectedLaunchServices;

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
      # Closure guard for the freeform layer: a brand-new CustomUserPreferences
      # domain (a whole `defaults write` target injected by an automated commit)
      # fails here, the gap a per-key check inside known domains cannot see.
      (helpers.assertTest "darwin-settings-CustomUserPreferences-domainset"
        (builtins.attrNames custom == [
          "NSGlobalDomain"
          "com.apple.CrashReporter"
          "com.apple.desktopservices"
          "com.apple.finder"
          "com.apple.frameworks.diskimages"
          "com.apple.screencapture"
        ])
        "system.defaults.CustomUserPreferences domains drifted from the locked set: have ${builtins.toJSON (builtins.attrNames custom)}")
    ];

  securityChecks = [
    (expectValue "security-sudo-touchid"
      cfg.security.pam.services.sudo_local.touchIdAuth
      true)
    (expectValue "security-firewall-enable"
      cfg.networking.applicationFirewall.enable
      true)
    (expectValue "security-firewall-stealth-mode"
      cfg.networking.applicationFirewall.enableStealthMode
      true)
    (expectValue "security-firewall-block-all-incoming"
      cfg.networking.applicationFirewall.blockAllIncoming
      false)
    (expectValue "security-firewall-allow-signed"
      cfg.networking.applicationFirewall.allowSigned
      true)
    (expectValue "security-firewall-allow-signed-app"
      cfg.networking.applicationFirewall.allowSignedApp
      true)

    # Gatekeeper is re-enabled CONDITIONALLY -- only when spctl reports it is
    # currently disabled. Lock in the guard so a refactor cannot turn this into
    # an unconditional toggle, and pin that activation never DISABLES Gatekeeper.
    (helpers.assertTest "darwin-settings-gatekeeper-conditional-reenable"
      (lib.hasInfix "spctl --status" postActivation
        && lib.hasInfix "grep -q 'disabled'" postActivation)
      "Gatekeeper re-enable should stay guarded behind an spctl --status | grep -q 'disabled' check")
    (expectActivation "gatekeeper-master-enable" "spctl --master-enable")
    (helpers.assertTest "darwin-settings-gatekeeper-not-disabled"
      (!(lib.hasInfix "spctl --master-disable" postActivation))
      "activation must never disable Gatekeeper (spctl --master-disable)")
  ];

  # skhd global hotkeys. The eval-test locks in the Finder cut/paste mode; here
  # we cover the launcher prefix, the power/reload utilities, a representative
  # launcher, and the host-injected Ghostty split bindings -- all of which would
  # otherwise drift with green CI.
  hotkeyChecks = [
    (helpers.assertTest "darwin-settings-skhd-launcher-prefix"
      (lib.hasInfix "ctrl + alt + shift" skhdConfig)
      "skhd should keep the ctrl+alt+shift launcher prefix")
    (helpers.assertTest "darwin-settings-skhd-display-sleep"
      (lib.hasInfix "pmset displaysleepnow" skhdConfig)
      "skhd should bind a display-sleep-now power action")
    (helpers.assertTest "darwin-settings-skhd-reload"
      (lib.hasInfix "skhd --reload" skhdConfig)
      "skhd should bind a config-reload action")
    (helpers.assertTest "darwin-settings-skhd-raycast-launcher"
      (lib.hasInfix ''open -a "Raycast"'' skhdConfig)
      "skhd should keep the Raycast launcher binding")
    (helpers.assertTest "darwin-settings-skhd-host-ghostty-split"
      (lib.hasInfix "ctrl + alt + shift - e [" skhdConfig
        && lib.hasInfix ''-k "cmd - d"'' skhdConfig)
      "skhd should include the host-injected Ghostty split controls")
  ];

  powerManagementChecks =
    map (param: expectActivation "pmset-${param}" param) expectedPmsetParams
    ++ lib.imap0
      (i: cmd: expectActivation "pmset-cmd-${toString i}" cmd)
      expectedPmsetCommands;

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
    (helpers.assertTest "darwin-settings-rime-squirrel-package"
      (hasPackage "squirrel" cfg.environment.systemPackages)
      "rime should install the Squirrel input method into systemPackages")
    (expectActivation "rime-input-methods-dir" "/Library/Input Methods")
    (expectActivation "rime-squirrel-link" ''ln -s "$source" "$target"'')
    (helpers.assertTest "darwin-settings-rime-user-config-sync"
      (
        let act = home.home.activation.rimeUserConfig.data;
        in lib.hasInfix "Library/Rime" act && lib.hasInfix "rsync" act
      )
      "rime should rsync the MyRime-main tree into ~/Library/Rime on activation")
  ];

  mouseDisplayChecks =
    let
      agents = home.launchd.agents;
      argsHaveApp = agent: appName:
        lib.any (a: lib.hasInfix appName a) agent.config.ProgramArguments;
      backgroundLaunch = agent:
        agent.enable == true
        && agent.config.RunAtLoad == true
        && builtins.elem "/usr/bin/open" agent.config.ProgramArguments
        && builtins.elem "-g" agent.config.ProgramArguments;
    in
    [
      (expectValue "mouse-display-enabled" cfg.martin.mouseDisplay.enable true)
      (helpers.assertTest "darwin-settings-betterdisplay-agent"
        (
          (agents ? betterdisplay)
          && backgroundLaunch agents.betterdisplay
          && argsHaveApp agents.betterdisplay "BetterDisplay.app"
        )
        "BetterDisplay should be a background (open -g) LaunchAgent that runs at load")
      (helpers.assertTest "darwin-settings-bettermouse-agent"
        (
          (agents ? bettermouse)
          && backgroundLaunch agents.bettermouse
          && argsHaveApp agents.bettermouse "BetterMouse.app"
        )
        "BetterMouse should be a background (open -g) LaunchAgent that runs at load")
    ];

  checks =
    systemDefaultsChecks
    ++ customPreferenceChecks
    ++ securityChecks
    ++ hotkeyChecks
    ++ powerManagementChecks
    ++ fontChecks
    ++ rimeChecks
    ++ mouseDisplayChecks;
in
helpers.testSuite "darwin-settings" checks
