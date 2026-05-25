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
{ pkgs, lib, self, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };

  user = "martinfan";

  evalsOk = drv:
    let r = builtins.tryEval (toString drv.drvPath);
    in r.success && r.value != "";

  hasPackage = name: packages:
    lib.any (pkg: lib.getName pkg == name) packages;

  homeChecks = prefix: homeConfig: expectedHomeDirectory: [
    (helpers.assertTest "${prefix}-home-username"
      (homeConfig.home.username == user)
      "${prefix} Home Manager username should match ${user}")

    (helpers.assertTest "${prefix}-home-directory"
      (homeConfig.home.homeDirectory == expectedHomeDirectory)
      "${prefix} Home Manager home directory should match the platform")

    (helpers.assertTest "${prefix}-has-git-package"
      (hasPackage "git" homeConfig.home.packages)
      "${prefix} Home Manager package list should include git")

    (helpers.assertTest "${prefix}-has-mgrep-package"
      (hasPackage "mgrep" homeConfig.home.packages)
      "${prefix} Home Manager package list should include mgrep")

    (helpers.assertTest "${prefix}-has-starship-package"
      (hasPackage "starship" homeConfig.home.packages)
      "${prefix} Home Manager package list should include starship")

    (helpers.assertTest "${prefix}-excludes-jj-starship-package"
      (!(hasPackage "jj-starship" homeConfig.home.packages))
      "${prefix} Home Manager package list should not include jj-starship")

    (helpers.assertTest "${prefix}-home-zsh-enabled"
      (homeConfig.programs.zsh.enable == true)
      "${prefix} Home Manager should own zsh config")

    (helpers.assertTest "${prefix}-home-zsh-history-substring-enabled"
      (homeConfig.programs.zsh.historySubstringSearch.enable == true)
      "${prefix} Home Manager should enable declarative history substring search")

    (helpers.assertTest "${prefix}-home-zoxide-enabled"
      (homeConfig.programs.zoxide.enable == true)
      "${prefix} Home Manager should enable zoxide integration")

    (helpers.assertTest "${prefix}-home-git-enabled"
      (homeConfig.programs.git.enable == true)
      "${prefix} Home Manager should own git config")

    (helpers.assertTest "${prefix}-home-jujutsu-enabled"
      (homeConfig.programs.jujutsu.enable == true)
      "${prefix} Home Manager should own jj config")

    (helpers.assertTest "${prefix}-home-tmux-enabled"
      (homeConfig.programs.tmux.enable == true)
      "${prefix} Home Manager should own tmux config")

    (helpers.assertTest "${prefix}-home-ghostty-config"
      (builtins.hasAttr "ghostty/config" homeConfig.xdg.configFile)
      "${prefix} Home Manager should own Ghostty config text")

    (helpers.assertTest "${prefix}-agent-skills-enabled"
      (homeConfig.programs.agent-skills.enable == true)
      "${prefix} should enable agent-skills")

    (helpers.assertTest "${prefix}-agent-skills-source-dotfiles-pi"
      (homeConfig.programs.agent-skills.sources ? dotfiles-pi)
      "${prefix} should configure dotfiles-pi skill source")

    (helpers.assertTest "${prefix}-agent-skills-source-dotfiles-claude"
      (homeConfig.programs.agent-skills.sources ? dotfiles-claude)
      "${prefix} should configure dotfiles-claude skill source")

    (helpers.assertTest "${prefix}-agent-skills-source-mp-productivity"
      (homeConfig.programs.agent-skills.sources ? mp-productivity)
      "${prefix} should configure the Matt Pocock productivity skill source")

    (helpers.assertTest "${prefix}-agent-skills-prefers-grill-with-docs"
      (
        let
          enabled = homeConfig.programs.agent-skills.skills.enable;
          explicit = homeConfig.programs.agent-skills.skills.explicit;
        in
        builtins.hasAttr "grill-with-docs" explicit
        && !(builtins.elem "grill-me" enabled)
        && !(builtins.hasAttr "grill-me" explicit)
      )
      "${prefix} should expose grill-with-docs explicitly but not the older grill-me skill")

    (helpers.assertTest "${prefix}-agent-skills-agents-target"
      (homeConfig.programs.agent-skills.targets.agents.enable == true)
      "${prefix} should enable the shared agents skill target")

    (helpers.assertTest "${prefix}-agent-skills-claude-target"
      (homeConfig.programs.agent-skills.targets.claude.enable == true)
      "${prefix} should enable the Claude skill target")

    (helpers.assertTest "${prefix}-agent-skills-codex-target"
      (homeConfig.programs.agent-skills.targets.codex.enable == true)
      "${prefix} should enable the Codex skill target")

    (helpers.assertTest "${prefix}-agent-skills-pi-target"
      (homeConfig.programs.agent-skills.targets.pi.dest == ".pi/agent/skills")
      "${prefix} should configure the Oh My Pi skill target")
  ];

  darwinConfig = self.darwinConfigurations."f".config;
  darwinHome = darwinConfig.home-manager.users.${user};
  darwinSkhdConfig = darwinConfig.services.skhd.skhdConfig;
  darwinRimePostActivation = darwinConfig.system.activationScripts.postActivation.text;
  darwinRimeUserActivation = darwinHome.home.activation.rimeUserConfig.data;
  darwinBetterMouseSeedActivation = darwinHome.home.activation.bettermouseSeed.data;
  darwinBetterMouseLaunchd = darwinHome.launchd.agents.bettermouse.config;
  darwinGhosttyConfig = darwinHome.xdg.configFile."ghostty/config".text;

  darwinChecks = [
    (helpers.assertTest "darwin-f-evaluates"
      (evalsOk self.darwinConfigurations."f".system)
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
      (
        "Darwin BetterMouse profile should point at the live imported settings source, "
          + "not the removed nix-config/personal-settings-main tree"
      ))

    (helpers.assertTest "darwin-bettermouse-seed-activation"
      (
        lib.hasInfix ''src="/Users/${user}/MyRime-main/better_mouse_setting_bm_cfg_4958.plist"''
          darwinBetterMouseSeedActivation
        && lib.hasInfix ''.nix-seed-source'' darwinBetterMouseSeedActivation
        && lib.hasInfix ''run install -m 0644 "$src" "/Users/${user}/Library/Application Support/BetterMouse/bm_cfg.plist"''
          darwinBetterMouseSeedActivation
      )
      "Darwin BetterMouse activation should seed the exported profile idempotently")

    (helpers.assertTest "darwin-bettermouse-launchd-agents"
      (
        let args = darwinBetterMouseLaunchd.ProgramArguments;
        in
        builtins.hasAttr "betterdisplay" darwinHome.launchd.agents
          && builtins.hasAttr "bettermouse" darwinHome.launchd.agents
          && lib.any (arg: lib.hasSuffix "/Applications/BetterMouse.app" arg) args
          && builtins.elem "/Users/${user}/Library/Application Support/BetterMouse/bm_cfg.plist" args
          && darwinBetterMouseLaunchd.RunAtLoad == true
          && darwinBetterMouseLaunchd.StandardOutPath
          == "/Users/${user}/Library/Logs/nix-managed-apps/bettermouse.stdout.log"
      )
      "Darwin BetterMouse launchd agent should open the app with the seeded profile")

    (helpers.assertTest "darwin-rime-enabled"
      (
        darwinConfig.martin.rime.enable == true
          && toString darwinConfig.martin.rime.config == "/Users/${user}/MyRime-main"
      )
      "Darwin should enable Rime with the live MyRime-main config source")

    (helpers.assertTest "darwin-rime-squirrel-system-package"
      (hasPackage "squirrel" darwinConfig.environment.systemPackages)
      "Darwin system packages should include the packaged Squirrel input method")

    (helpers.assertTest "darwin-rime-post-activation"
      (
        lib.hasInfix ''input_methods_dir="/Library/Input Methods"'' darwinRimePostActivation
          && lib.hasInfix ''target="/Library/Input Methods/Squirrel.app"'' darwinRimePostActivation
          && lib.hasInfix ''source="/nix/store/'' darwinRimePostActivation
          && lib.hasInfix ''/Library/Input Methods/Squirrel.app"'' darwinRimePostActivation
          && lib.hasInfix ''backup-before-nix'' darwinRimePostActivation
          && lib.hasInfix ''ln -s "$source" "$target"'' darwinRimePostActivation
      )
      "Darwin Rime activation should idempotently link Squirrel into /Library/Input Methods")

    (helpers.assertTest "darwin-rime-user-activation"
      (
        lib.hasInfix ''run mkdir -p "/Users/${user}/Library/Rime"'' darwinRimeUserActivation
          && lib.hasInfix ''if [ ! -d "/Users/${user}/MyRime-main" ]; then'' darwinRimeUserActivation
          && lib.hasInfix ''--exclude '*.userdb/' '' darwinRimeUserActivation
          && lib.hasInfix ''"/Users/${user}/MyRime-main/" "/Users/${user}/Library/Rime/"'' darwinRimeUserActivation
          && lib.hasInfix ''Squirrel" --reload || true'' darwinRimeUserActivation
      )
      "Darwin Rime Home Manager activation should sync user config and redeploy Squirrel")

    (helpers.assertTest "darwin-zsh-enabled"
      (darwinConfig.programs.zsh.enable == true)
      "Darwin should enable zsh at the system level")

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

    (helpers.assertTest "darwin-ghostty-generated-config"
      (
        lib.hasInfix "# Ghostty config — generated by Home Manager" darwinGhosttyConfig
          && lib.hasInfix "theme = rose-pine-moon" darwinGhosttyConfig
          && lib.hasInfix "bold-is-bright = false" darwinGhosttyConfig
          && lib.hasInfix "background-opacity = 0.0" darwinGhosttyConfig
          && lib.hasInfix "background-blur = macos-glass-clear" darwinGhosttyConfig
          && lib.hasInfix ''font-family = "Maple Mono NF CN"'' darwinGhosttyConfig
          && lib.hasInfix "font-thicken = true" darwinGhosttyConfig
          && lib.hasInfix "scrollback-limit = 500000" darwinGhosttyConfig
          && lib.hasInfix "shell-integration-features = cursor,sudo,title" darwinGhosttyConfig
          && lib.hasInfix "quick-terminal-position = top" darwinGhosttyConfig
          && lib.hasInfix "keybind = cmd+d=new_split:right" darwinGhosttyConfig
      )
      "Darwin Ghostty config should render the host's theme, font, transparency, and keybind settings")

    (helpers.assertTest "darwin-ghostty-custom-theme-file"
      (
        builtins.hasAttr "ghostty/themes/rose-pine-moon" darwinHome.xdg.configFile
          && lib.hasInfix "background = 232136" darwinHome.xdg.configFile."ghostty/themes/rose-pine-moon".text
          && lib.hasInfix "palette = 15=e0def4" darwinHome.xdg.configFile."ghostty/themes/rose-pine-moon".text
      )
      "Darwin Ghostty should install the configured rose-pine-moon custom theme file")

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
  ] ++ (homeChecks "darwin" darwinHome "/Users/${user}");

  wslConfig = self.nixosConfigurations.wsl.config;
  x230Config = self.nixosConfigurations.x230.config;
  vmConfig = self.nixosConfigurations.vm-aarch64-utm.config;
  wslHome = wslConfig.home-manager.users.${user};
  x230Home = x230Config.home-manager.users.${user};
  vmHome = vmConfig.home-manager.users.${user};

  nixosChecks = [
    (helpers.assertTest "nixos-wsl-evaluates"
      (evalsOk self.nixosConfigurations.wsl.config.system.build.toplevel)
      "nixosConfigurations.wsl.toplevel should evaluate")

    (helpers.assertTest "nixos-x230-evaluates"
      (evalsOk self.nixosConfigurations.x230.config.system.build.toplevel)
      "nixosConfigurations.x230.toplevel should evaluate")

    (helpers.assertTest "nixos-vm-aarch64-utm-evaluates"
      (evalsOk self.nixosConfigurations.vm-aarch64-utm.config.system.build.toplevel)
      "nixosConfigurations.vm-aarch64-utm.toplevel should evaluate")

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

in
helpers.testSuite "configurations-eval" (darwinChecks ++ nixosChecks)
