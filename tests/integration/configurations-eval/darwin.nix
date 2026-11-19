ctx:

let
  inherit (ctx) helpers lib evalsOk darwinSystem darwinConfig darwinHome user hasPackage;
in
[
  (helpers.assertTest "darwin-f-evaluates"
    (evalsOk darwinSystem)
    "darwinConfigurations.f.system should evaluate")

  (helpers.assertTest "darwin-primary-user"
    (darwinConfig.system.primaryUser == user)
    "Darwin primary user should match ${user}")

  (helpers.assertTest "darwin-codex-layered-config"
    (
      let
        codexDefaults = darwinConfig.environment.etc."codex/config.toml".text;
      in
      builtins.hasAttr "codex/config.toml" darwinConfig.environment.etc
      && lib.hasInfix "[lsp.servers.tsrs]" codexDefaults
      && !(lib.hasInfix "[lsp.servers.vue]" codexDefaults)
      && !(lib.hasInfix "[lsp.servers.haskell]" codexDefaults)
      && lib.hasInfix "[mcp_servers.fff]" codexDefaults
      && !(lib.hasInfix "@PI_" codexDefaults)
      && !(lib.hasInfix "gpt-5." codexDefaults)
      && !(lib.hasInfix ''
        model = "''
        codexDefaults)
      && !(lib.hasInfix "model_reasoning_effort =" codexDefaults)
    )
    "Darwin should keep Codex machine defaults in /etc without locking the user model choice")

  (helpers.assertTest "darwin-agent-routing-gpt-6-only"
    (
      let
        crush = darwinHome.xdg.configFile."crush/crush.json".text;
        zed = builtins.toJSON darwinHome.programs.zed-editor.userSettings;
        rendered = crush + zed;
      in
      lib.all (model: lib.hasInfix model rendered) [
        "gpt-6-astra"
        "gpt-6-sol"
        "gpt-6-luna"
      ]
      && !(lib.hasInfix "gpt-5." rendered)
    )
    "Darwin Crush and Zed adapters should render only GPT-6 semantic routes")

  # BetterMouse and BetterDisplay self-update via Sparkle in /Applications,
  # so both stay GUI-managed outside Nix (ADR-0011, ADR-0012).
  (helpers.assertTest "darwin-bettermouse-not-nix-managed"
    (
      !(darwinConfig.martin ? mouseDisplay)
      && !(lib.any (p: lib.getName p == "bettermouse")
        darwinConfig.environment.systemPackages)
    )
    "Darwin should not reintroduce BetterMouse as a Nix-managed app")

  (helpers.assertTest "darwin-betterdisplay-not-nix-managed"
    (
      !(darwinConfig.martin ? display)
      && !(lib.any (p: lib.getName p == "betterdisplay")
        darwinConfig.environment.systemPackages)
    )
    "Darwin should not reintroduce BetterDisplay as a Nix-managed app")

  (helpers.assertTest "darwin-zsh-enabled"
    (darwinConfig.programs.zsh.enable == true)
    "Darwin should enable zsh at the system level")

  (helpers.assertTest "darwin-security-gatekeeper-not-disabled"
    (
      let
        diskImages = darwinConfig.system.defaults.CustomUserPreferences."com.apple.frameworks.diskimages";
      in
      darwinConfig.system.defaults.LaunchServices.LSQuarantine == true
      && diskImages."skip-verify" == false
      && diskImages."skip-verify-locked" == false
      && diskImages."skip-verify-remote" == false
      && !(lib.hasInfix "spctl --master-disable" darwinConfig.system.activationScripts.postActivation.text)
      && lib.hasInfix "spctl --master-enable" darwinConfig.system.activationScripts.postActivation.text
    )
    "Darwin activation should keep Gatekeeper/quarantine and disk image verification enabled")

  (helpers.assertTest "darwin-application-firewall-hardened"
    (
      darwinConfig.networking.applicationFirewall.enable == true
      && darwinConfig.networking.applicationFirewall.enableStealthMode == true
      && darwinConfig.networking.applicationFirewall.blockAllIncoming == false
    )
    "Darwin application firewall should be enabled with stealth mode")

  (helpers.assertTest "darwin-background-churn-reduced"
    (
      let
        activation = darwinConfig.system.activationScripts.postActivation.text;
        launchdEntries = darwinConfig.martin.darwinBaseline.activationState.launchdDisabledDomains;
        hasLaunchdLabel = label: lib.any (entry: builtins.elem label entry.labels) launchdEntries;
      in
      darwinConfig.martin.backgroundServices.cleanMyMacManualOnly == true
      && hasLaunchdLabel "com.macpaw.CleanMyMac5.HealthMonitor"
      && hasLaunchdLabel "com.macpaw.CleanMyMac5.Agent"
      && lib.hasInfix "/var/db/nix-config" activation
      && lib.hasInfix "background-services-disabled-by-nix" activation
      && lib.hasInfix "com.macpaw.CleanMyMac5.HealthMonitor" activation
      && lib.hasInfix "com.macpaw.CleanMyMac5.Agent" activation
      && lib.hasInfix "launchctl print-disabled" activation
      && lib.hasInfix "managed_before=1" activation
      && lib.hasInfix "grep -Fxq \"$domain\" \"$state_file\"" activation
      && lib.hasInfix "launchctl enable" activation
    )
    "Darwin should keep CleanMyMac background churn out of the baseline with reversible launchd state")

  (helpers.assertTest "darwin-spotlight-dev-tree-exclusions"
    (
      let
        activation = darwinHome.home.activation.spotlightExclusions.data;
        markerEntries = darwinConfig.martin.darwinBaseline.activationState.pathMarkers;
        spotlightMarker = lib.findFirst (marker: marker.name == "spotlightExclusions") null markerEntries;
      in
      darwinConfig.martin.spotlight.enable == true
      && spotlightMarker != null
      && spotlightMarker.enable == true
      && builtins.elem "/Users/${user}/gosh-my-pi" spotlightMarker.paths
      && builtins.elem "/Users/${user}/.codex" spotlightMarker.paths
      && builtins.elem "/Users/${user}/gosh-my-pi" darwinConfig.martin.spotlight.excludedPaths
      && builtins.elem "/Users/${user}/.codex" darwinConfig.martin.spotlight.excludedPaths
      && builtins.elem ".metadata_never_index" darwinHome.programs.git.ignores
      && lib.hasInfix "managed by nix-config martin.spotlight" activation
      && lib.hasInfix "spotlight-exclusions" activation
      && lib.hasInfix "DRY_RUN" activation
      && lib.hasInfix "/usr/bin/grep -Fxq \"$marker_text\" \"$marker\"" activation
      && !(lib.hasInfix "grep -qx" activation)
      && lib.hasInfix "elif [ ! -e \"$marker\" ]" activation
    )
    "Darwin should mark dev/cache trees as user-context reversible Spotlight exclusions without clobbering existing markers")

  (helpers.assertTest "darwin-health-check-launch-agent"
    (
      darwinConfig.martin.healthCheck.enable == true
      && builtins.hasAttr "macos-health-report" darwinHome.launchd.agents
      && darwinHome.launchd.agents.macos-health-report.config.RunAtLoad == true
      && darwinHome.launchd.agents.macos-health-report.config.StartCalendarInterval.Hour == 9
      && darwinHome.launchd.agents.macos-health-report.config.StartCalendarInterval.Minute == 15
      && lib.hasSuffix "/Library/Logs/nix-managed-health/launchd.stdout.log" darwinHome.launchd.agents.macos-health-report.config.StandardOutPath
      && lib.hasSuffix "/Library/Logs/nix-managed-health/launchd.stderr.log" darwinHome.launchd.agents.macos-health-report.config.StandardErrorPath
      && lib.hasInfix "nix-managed-health" darwinConfig.system.activationScripts.postActivation.text
    )
    "Darwin should install the daily macOS health report LaunchAgent")

  (helpers.assertTest "darwin-starship-enabled"
    (darwinHome.programs.starship.enable == true)
    "Darwin Home Manager should enable the migrated Starship prompt")

  (helpers.assertTest "darwin-starship-glass-chip-layout"
    (
      let
        settings = darwinHome.programs.starship.settings;
      in
      lib.hasPrefix "$directory" settings.format
      && !(lib.hasInfix "\${custom.shell_name}" settings.format)
      && lib.hasInfix "$directory\${custom.directory_end}\${custom.git_branch}$git_status\${custom.git_end}" settings.format
      && lib.hasInfix "\${custom.jj}" settings.format
      && lib.hasInfix "$line_break$character" settings.format
      && lib.hasInfix "" settings.directory.format
    )
    "Darwin Starship config should expose the compact transparent chip layout")

  (helpers.assertTest "darwin-starship-jj-direct-custom"
    (
      let jj = darwinHome.programs.starship.settings.custom.jj;
      in
      jj.when == "jj root >/dev/null 2>&1"
      && lib.hasInfix "jj log" jj.command
      && !(lib.hasInfix "jj-starship" jj.command)
      && !(lib.hasInfix "jj-starship" jj.when)
    )
    "Darwin Starship Jujutsu prompt should call jj directly, not jj-starship")

  (helpers.assertTest "darwin-starship-git-branch-hidden-in-jj"
    (
      let
        settings = darwinHome.programs.starship.settings;
        git = settings.custom.git_branch;
      in
      settings.git_branch.disabled == true
      && lib.hasInfix "$all_status$ahead_behind" settings.git_status.format
      && git.when == "! jj root >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1"
      && lib.hasInfix "git symbolic-ref" git.command
    )
    "Darwin Starship Git branch chip should be hidden inside Jujutsu repos")

  # skhd's CGEventTap conflicts with BetterMouse on this host, so keep the
  # daemon off unless explicitly flipped in both host config and test.
  (helpers.assertTest "darwin-skhd-disabled-for-bettermouse"
    (
      darwinConfig.martin.skhd.enable == false
      && darwinConfig.services.skhd.enable == false
    )
    "Darwin should keep skhd off so its event tap cannot conflict with BetterMouse")

  (helpers.assertTest "darwin-hammerspoon-installed"
    (
      darwinConfig.martin.hammerspoon.enable == true
      && hasPackage "hammerspoon" darwinConfig.environment.systemPackages
    )
    "Darwin system packages should include Hammerspoon for rich macOS automation")

  (helpers.assertTest "darwin-hammerspoon-config"
    (
      builtins.hasAttr ".hammerspoon/init.lua" darwinHome.home.file
      && lib.hasInfix "hs.pathwatcher.new" darwinHome.home.file.".hammerspoon/init.lua".text
      && lib.hasInfix "_G.martin" darwinHome.home.file.".hammerspoon/init.lua".text
    )
    "Darwin Home Manager should own the Hammerspoon init.lua")

  # Forcing home.file triggers agent-skills IFD on the host platform, so check
  # the shared jj skill wiring on the native Darwin config.
  (helpers.assertTest "darwin-installs-jj-skill"
    (
      darwinHome.home.file ? ".claude/skills/jj"
      && darwinHome.home.file ? ".agents/skills/jj"
      && darwinHome.home.file ? ".config/crush/skills/jj"
      && darwinHome.home.file ? ".config/opencode/skills/jj"
      && !(darwinHome.home.file ? ".factory/skills/jj")
      && darwinHome.home.file ? ".pi/agent/skills/jj"
    )
    "Darwin should install the locally-authored jj skill into the picker dirs")

  (helpers.assertTest "darwin-brew-default-disabled"
    (darwinConfig.martin.brew.homebrew.enable == false)
    "Homebrew emergency scaffold should remain disabled by default")

  (helpers.assertTest "darwin-has-sourcegraph-amp"
    (hasPackage "sourcegraph-amp" darwinHome.home.packages)
    "Darwin Home Manager packages should include sourcegraph-amp")

  (helpers.assertTest "darwin-has-crush"
    (hasPackage "crush" darwinHome.home.packages)
    "Darwin Home Manager packages should include Crush from Charm's NUR repo")

  (helpers.assertTest "darwin-has-oh-my-pi"
    (hasPackage "oh-my-pi" darwinHome.home.packages)
    "Darwin Home Manager packages should include oh-my-pi")

  (helpers.assertTest "darwin-has-uv"
    (hasPackage "uv-bin" darwinHome.home.packages)
    "Darwin Home Manager packages should include the official uv release for Python package management")

  (helpers.assertTest "darwin-registers-drafts-mcp"
    (lib.hasInfix "drafts-mcp-server" darwinHome.home.activation.claudeMcp.data)
    "Darwin Home Manager should register the Drafts MCP server")

  (helpers.assertTest "darwin-zed-uses-zed-nightly-bin"
    (
      darwinHome.programs.zed-editor.enable == true
      && lib.getName darwinHome.programs.zed-editor.package == "zed-nightly-bin"
    )
    "Darwin Home Manager should pin Zed to the prebuilt nightly binary")

  (helpers.assertTest "darwin-zed-settings-force-managed"
    (darwinHome.xdg.configFile."zed/settings.json".force == true)
    "Darwin Home Manager should force-manage Zed settings so an equivalent regular file cannot block activation")
]
