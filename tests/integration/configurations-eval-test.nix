# Integration test: every flake configuration evaluates and exposes the
# attributes the active architecture commits to.
#
# Per ARCHITECTURE.md, Home Manager now owns selected shell/editor-adjacent
# config text (zsh, git, tmux, Ghostty, Starship) while still leaving mutable
# auth/runtime app state outside the store. The asserts below cover what the
# current architecture commits to:
#   * each flake configuration evaluates end-to-end (drvPath computable)
#   * currentSystemUser flows into home-manager + system user options
#   * agent-skills DSL is wired with the documented sources and targets
#   * common packages (git, mgrep) are present in home.packages
#   * migrated Home Manager program modules are enabled
#   * darwin-only agent packages are gated to darwin
#   * system-level zsh stays on (this IS owned by Nix, not unmanaged dotfiles)
{ pkgs
, lib
, evalScope ? "auto"
, darwinConfigurationInput ? null
, wslConfigurationInput ? null
, x230ConfigurationInput ? null
, vmConfigurationInput ? null
, ...
}:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };

  user = "martinfan";
  selectedScope =
    if evalScope == "auto" then
      (if pkgs.stdenv.isDarwin then "darwin" else "nixos")
    else evalScope;

  darwinConfiguration = if selectedScope == "darwin" then darwinConfigurationInput else null;
  darwinConfig = if darwinConfiguration != null then darwinConfiguration.config else null;
  darwinSystem = if darwinConfiguration != null then darwinConfiguration.system else null;
  darwinHome = if darwinConfig != null then darwinConfig.home-manager.users.${user} else null;
  darwinSkhdConfig = if darwinConfig != null then darwinConfig.services.skhd.skhdConfig else null;
  wslConfiguration = if selectedScope == "nixos" then wslConfigurationInput else null;
  x230Configuration = if selectedScope == "nixos" then x230ConfigurationInput else null;
  vmConfiguration = if selectedScope == "nixos" then vmConfigurationInput else null;
  wslConfig = if wslConfiguration != null then wslConfiguration.config else null;
  x230Config = if x230Configuration != null then x230Configuration.config else null;
  vmConfig = if vmConfiguration != null then vmConfiguration.config else null;
  wslHome = if wslConfig != null then wslConfig.home-manager.users.${user} else null;
  x230Home = if x230Config != null then x230Config.home-manager.users.${user} else null;
  vmHome = if vmConfig != null then vmConfig.home-manager.users.${user} else null;

  evalsOk = drv:
    let r = builtins.tryEval (toString drv.drvPath);
    in r.success && r.value != "";

  # A config's system.build.toplevel can only be eval-checked on a builder of
  # its own platform. home-manager's agent-skills bundle resolves bundlePath via
  # import-from-derivation, which builds a platform-stamped source, so computing
  # a foreign-platform toplevel's drvPath here aborts with a "platform mismatch"
  # rather than a catchable eval error. The `system != pkgs.system` short-circuit
  # skips the foreign case; the CI check matrix runs this suite on every
  # supported system, so each toplevel is still eval-verified on its native host.
  toplevelEvaluatesOnNative = name: system: config:
    helpers.assertTest "nixos-${name}-evaluates"
      (system != pkgs.system || evalsOk config.system.build.toplevel)
      "nixosConfigurations.${name}.toplevel should evaluate (checked on its native builder)";

  hasPackage = name: packages:
    lib.any (pkg: lib.getName pkg == name) packages;

  homeChecks = prefix: homeConfig: expectedHomeDirectory:
    let
      homeData = homeConfig.home;
      homePrograms = homeConfig.programs;
      homeActivation = homeData.activation;
      homeXdg = homeConfig.xdg;
      homePackageSet = builtins.listToAttrs (map
        (pkg: {
          name = lib.getName pkg;
          value = true;
        })
        homeData.packages);
      hasHomePackage = name: builtins.hasAttr name homePackageSet;
    in
    [
      (helpers.assertTest "${prefix}-home-username"
        (homeData.username == user)
        "${prefix} Home Manager username should match ${user}")

      (helpers.assertTest "${prefix}-home-directory"
        (homeData.homeDirectory == expectedHomeDirectory)
        "${prefix} Home Manager home directory should match the platform")

      (helpers.assertTest "${prefix}-has-git-package"
        (hasHomePackage "git")
        "${prefix} Home Manager package list should include git")

      (helpers.assertTest "${prefix}-has-mgrep-package"
        (hasHomePackage "mgrep")
        "${prefix} Home Manager package list should include mgrep")

      (helpers.assertTest "${prefix}-has-starship-package"
        (hasHomePackage "starship")
        "${prefix} Home Manager package list should include starship")

      (helpers.assertTest "${prefix}-excludes-jj-starship-package"
        (!(hasHomePackage "jj-starship"))
        "${prefix} Home Manager package list should not include jj-starship")

      (helpers.assertTest "${prefix}-home-zsh-enabled"
        (homePrograms.zsh.enable == true)
        "${prefix} Home Manager should own zsh config")

      (helpers.assertTest "${prefix}-home-zsh-history-substring-enabled"
        (homePrograms.zsh.historySubstringSearch.enable == true)
        "${prefix} Home Manager should enable declarative history substring search")

      (helpers.assertTest "${prefix}-home-zoxide-enabled"
        (homePrograms.zoxide.enable == true)
        "${prefix} Home Manager should enable zoxide integration")

      (helpers.assertTest "${prefix}-home-git-enabled"
        (homePrograms.git.enable == true)
        "${prefix} Home Manager should own git config")

      (helpers.assertTest "${prefix}-home-jujutsu-enabled"
        (homePrograms.jujutsu.enable == true)
        "${prefix} Home Manager should own jj config")

      (helpers.assertTest "${prefix}-home-tmux-enabled"
        (homePrograms.tmux.enable == true)
        "${prefix} Home Manager should own tmux config")

      (helpers.assertTest "${prefix}-home-ghostty-config"
        (builtins.hasAttr "ghostty/config" homeXdg.configFile)
        "${prefix} Home Manager should own Ghostty config text")

      (helpers.assertTest "${prefix}-agent-skills-enabled"
        (homePrograms.agent-skills.enable == true)
        "${prefix} should enable agent-skills")

      (helpers.assertTest "${prefix}-agent-skills-source-dotfiles-pi"
        (homePrograms.agent-skills.sources ? dotfiles-pi)
        "${prefix} should configure dotfiles-pi skill source")

      (helpers.assertTest "${prefix}-removes-lazygit"
        (
          let
            cfg = homePrograms.agent-skills;
            prune = homeActivation.claudePruneRemovedSkills.data;
          in
          !(cfg.sources ? dotfiles-claude)
          && !(builtins.hasAttr "lazygit" cfg.skills.explicit)
          && lib.hasInfix "lazygit" prune
        )
        "${prefix} should fully remove the lazygit skill: no dotfiles-claude source, no explicit entry, pruned from target dirs")

      (helpers.assertTest "${prefix}-agent-skills-source-mp-productivity"
        (homePrograms.agent-skills.sources ? mp-productivity)
        "${prefix} should configure the Matt Pocock productivity skill source")

      (helpers.assertTest "${prefix}-agent-skills-prefers-grill-with-docs"
        (
          let
            enabled = homePrograms.agent-skills.skills.enable;
            explicit = homePrograms.agent-skills.skills.explicit;
          in
          builtins.hasAttr "grill-with-docs" explicit
          && !(builtins.elem "grill-me" enabled)
          && !(builtins.hasAttr "grill-me" explicit)
        )
        "${prefix} should expose grill-with-docs explicitly but not the older grill-me skill")

      (helpers.assertTest "${prefix}-agent-skills-removes-git-workflow"
        (
          let cfg = homePrograms.agent-skills;
          in
          !(builtins.hasAttr "git-workflow" cfg.catalog)
          && !(builtins.elem "git-workflow" cfg.skills.enable)
          && !(builtins.hasAttr "git-workflow" cfg.skills.explicit)
        )
        "${prefix} should remove git-workflow from discovery and the active skill bundle")

      (helpers.assertTest "${prefix}-agent-skills-superpowers-brainstorming-only"
        (homePrograms.agent-skills.sources.superpowers.filter.nameRegex == "^(brainstorming)$")
        "${prefix} should not discover disabled superpowers workflow skills")

      (helpers.assertTest "${prefix}-agent-skills-effect-ts-devshell-scoped"
        (
          let cfg = homePrograms.agent-skills;
          in
          !(builtins.elem "effect-ts" cfg.skills.enableAll)
          && !(builtins.elem "effect-ts" cfg.skills.enable)
          && !(builtins.hasAttr "effect-ts" cfg.skills.explicit)
        )
        "${prefix} should not globally bundle effect-ts — it is per-project devShell-scoped (templates/effect-skills)")

      (helpers.assertTest "${prefix}-agent-skills-removed-prune-dry-run-safe"
        (
          let activation = homeActivation.claudePruneRemovedSkills.data;
          in
          lib.hasInfix "DRY_RUN" activation
          && lib.hasInfix "git-workflow" activation
          && !(lib.hasInfix "exit 0" activation)
        )
        "${prefix} should prune removed skills without mutating during Home Manager dry runs")

      (helpers.assertTest "${prefix}-claude-refactor-code-simplifier-deduped"
        (
          let activation = homeActivation.claudeDisableRefactorPluginCodeSimplifier.data;
          in
          lib.hasInfix "frad-dotclaude/refactor" activation
          && lib.hasInfix "code-simplifier.md" activation
          && lib.hasInfix "agents-disabled" activation
        )
        "${prefix} should park the refactor plugin's duplicate code-simplifier agent, keeping the official one")

      (helpers.assertTest "${prefix}-claude-disables-gitflow-git-plugins"
        (
          let activation = homeActivation.claudeDisableGlobalMcpPlugins.data;
          in
          lib.hasInfix "gitflow@frad-dotclaude" activation
          && lib.hasInfix "git@frad-dotclaude" activation
        )
        "${prefix} should disable the gitflow and git plugins on the global surface so their git-flow/commit skills leave Claude Code's startup catalog")

      (helpers.assertTest "${prefix}-agent-skills-agents-target"
        (homePrograms.agent-skills.targets.agents.enable == true)
        "${prefix} should enable the shared agents skill target")

      (helpers.assertTest "${prefix}-agent-skills-claude-target"
        (homePrograms.agent-skills.targets.claude.enable == true)
        "${prefix} should enable the Claude skill target")

      (helpers.assertTest "${prefix}-agent-skills-cursor-target"
        (homePrograms.agent-skills.targets.cursor.enable == true)
        "${prefix} should enable the Cursor skill target")

      (helpers.assertTest "${prefix}-agent-skills-codex-target"
        (homePrograms.agent-skills.targets.codex.enable == true)
        "${prefix} should enable the Codex skill target")

      (helpers.assertTest "${prefix}-agent-skills-crush-target"
        (homePrograms.agent-skills.targets.crush.dest == ".config/crush/skills")
        "${prefix} should configure the native Crush skill target")

      (helpers.assertTest "${prefix}-agent-skills-factory-target"
        (homePrograms.agent-skills.targets.factory.dest == ".factory/skills")
        "${prefix} should configure the native Factory/Droid skill target")

      (helpers.assertTest "${prefix}-agent-skills-opencode-target"
        (homePrograms.agent-skills.targets.opencode.dest == ".config/opencode/skills")
        "${prefix} should configure the native OpenCode skill target")

      (helpers.assertTest "${prefix}-agent-skills-pi-target"
        (homePrograms.agent-skills.targets.pi.dest == ".pi/agent/skills")
        "${prefix} should configure the Oh My Pi skill target")

      (helpers.assertTest "${prefix}-skill-router-installed"
        (hasHomePackage "skill-router")
        "${prefix} should install the skill-router CLI")

      (helpers.assertTest "${prefix}-skill-router-config-not-managed"
        (!(homeData.file ? ".config/skill-router/config.json"))
        "${prefix} should leave skill-router config.json user-owned; the CLI bundles its default config")

      (helpers.assertTest "${prefix}-lsp-activation-dry-run-safe"
        (
          let
            codex = homeActivation.codexLspConfig.data;
            desktopOk =
              if prefix == "darwin" then
                let desktop = homeActivation.claudeDesktopMcpScaffold.data;
                in
                lib.hasInfix "DRY_RUN" desktop
                && !(lib.hasInfix "exit 0" desktop)
              else
                !(homeActivation ? claudeDesktopMcpScaffold);
          in
          lib.hasInfix "DRY_RUN" codex
          && !(lib.hasInfix "exit 0" codex)
          && desktopOk
        )
        "${prefix} LSP activation scripts should respect Home Manager dry runs without exiting activation")
    ];

  darwinChecks = [
    (helpers.assertTest "darwin-f-evaluates"
      (evalsOk darwinSystem)
      "darwinConfigurations.f.system should evaluate")

    (helpers.assertTest "darwin-primary-user"
      (darwinConfig.system.primaryUser == user)
      "Darwin primary user should match ${user}")

    (helpers.assertTest "darwin-bettermouse-profile-source"
      (
        let profile = toString darwinConfig.martin.mouseDisplay.bettermouse.profile;
        in
        profile == "/Users/${user}/MyRime-main/better_mouse_setting_bm_cfg_4958.plist"
          && !(lib.hasInfix "/nix-config/personal-settings-main/" profile)
      )
      "Darwin BetterMouse profile should point at the live imported settings source, not the removed nix-config/personal-settings-main tree")

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

    (helpers.assertTest "darwin-skhd-enabled"
      (darwinConfig.services.skhd.enable == true)
      "Darwin should enable skhd for managed global hotkeys")

    (helpers.assertTest "darwin-skhd-finder-cut-mode"
      (
        lib.hasInfix ":: finder_cut" darwinSkhdConfig
          && lib.hasInfix ''cmd - x ['' darwinSkhdConfig
          && lib.hasInfix ''"finder" :'' darwinSkhdConfig
          && lib.hasInfix ''-k "cmd - c"'' darwinSkhdConfig
          && lib.hasInfix ''* ~'' darwinSkhdConfig
      )
      "Darwin skhd config should intercept Cmd-X only in Finder and copy the selected items")

    (helpers.assertTest "darwin-skhd-finder-native-move"
      (
        lib.hasInfix ''finder_cut < cmd - v ['' darwinSkhdConfig
          && lib.hasInfix ''-k "cmd + alt - v"'' darwinSkhdConfig
          && lib.hasInfix "finder_cut < escape ; default" darwinSkhdConfig
          && lib.hasInfix "finder_cut < f19 ; default" darwinSkhdConfig
      )
      "Darwin skhd config should map pending Finder paste to Finder's native move")

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

    # Native-config only: forcing the home.file spine makes agent-skills resolve
    # its bundlePath, an import-from-derivation that builds a platform-stamped
    # source. On aarch64-darwin the foreign x86_64-linux NixOS bundles cannot be
    # built, so this lives in darwinChecks rather than the cross-platform
    # homeChecks. The jj install is shared in claude.nix, so checking it once on
    # the native host covers every host's mechanism.
    (helpers.assertTest "darwin-installs-jj-skill"
      (
        darwinHome.home.file ? ".claude/skills/jj"
          && darwinHome.home.file ? ".agents/skills/jj"
          && darwinHome.home.file ? ".config/crush/skills/jj"
          && darwinHome.home.file ? ".config/opencode/skills/jj"
          && darwinHome.home.file ? ".factory/skills/jj"
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
      "Darwin Home Manager packages should include Crush from Charm NUR")

    (helpers.assertTest "darwin-has-oh-my-pi"
      (hasPackage "oh-my-pi" darwinHome.home.packages)
      "Darwin Home Manager packages should include oh-my-pi")

    (helpers.assertTest "darwin-zed-uses-zed-nightly-bin"
      (
        darwinHome.programs.zed-editor.enable == true
          && lib.getName darwinHome.programs.zed-editor.package == "zed-nightly-bin"
      )
      "Darwin Home Manager should pin Zed to the prebuilt nightly binary")

    (helpers.assertTest "darwin-zed-settings-force-managed"
      (darwinHome.xdg.configFile."zed/settings.json".force == true)
      "Darwin Home Manager should force-manage Zed settings so an equivalent regular file cannot block activation")
  ] ++ (homeChecks "darwin" darwinHome "/Users/${user}");

  nixosChecks = [
    (toplevelEvaluatesOnNative "wsl" "x86_64-linux" wslConfig)
    (toplevelEvaluatesOnNative "x230" "x86_64-linux" x230Config)
    (toplevelEvaluatesOnNative "vm-aarch64-utm" "aarch64-linux" vmConfig)

    (helpers.assertTest "wsl-host-name"
      (wslConfig.networking.hostName == "wsl")
      "WSL host name should remain wsl")

    (helpers.assertTest "wsl-default-user"
      (wslConfig.wsl.defaultUser == user)
      "WSL default user should come from currentSystemUser")

    (helpers.assertTest "wsl-zsh-enabled"
      (wslConfig.programs.zsh.enable == true)
      "WSL/NixOS should enable zsh at the system level")

    (helpers.assertTest "x230-host-name"
      (x230Config.networking.hostName == "x230")
      "x230 host name should remain x230")

    (helpers.assertTest "x230-zsh-enabled"
      (x230Config.programs.zsh.enable == true)
      "x230/NixOS should enable zsh at the system level")

    (helpers.assertTest "vm-aarch64-utm-host-name"
      (vmConfig.networking.hostName == "vm-aarch64-utm")
      "aarch64 UTM VM host name should remain vm-aarch64-utm")

    (helpers.assertTest "vm-aarch64-utm-zsh-enabled"
      (vmConfig.programs.zsh.enable == true)
      "aarch64 UTM VM should enable zsh at the system level")

    (helpers.assertTest "linux-excludes-darwin-only-agent-packages"
      (!(hasPackage "sourcegraph-amp" wslHome.home.packages))
      "Linux Home Manager packages should not include Darwin-only agent packages")

    (helpers.assertTest "linux-zed-editor-disabled"
      (
        wslHome.programs.zed-editor.enable == false
          && x230Home.programs.zed-editor.enable == false
          && vmHome.programs.zed-editor.enable == false
      )
      "Linux Home Manager should leave programs.zed-editor off — zed-nightly-bin is Darwin-only")

    (helpers.assertTest "linux-excludes-zed-nightly-bin-package"
      (
        !(hasPackage "zed-nightly-bin" wslHome.home.packages)
          && !(hasPackage "zed-nightly-bin" x230Home.home.packages)
          && !(hasPackage "zed-nightly-bin" vmHome.home.packages)
      )
      "Linux Home Manager package lists must never include the Darwin-only zed-nightly-bin")
  ]
  ++ (homeChecks "wsl" wslHome "/home/${user}")
  ++ (homeChecks "x230" x230Home "/home/${user}")
  ++ (homeChecks "vm-aarch64-utm" vmHome "/home/${user}");

  selectedChecks = if selectedScope == "darwin" then darwinChecks else
  if selectedScope == "nixos" then nixosChecks
  else darwinChecks ++ nixosChecks;
in
helpers.testSuite "configurations-eval" selectedChecks
