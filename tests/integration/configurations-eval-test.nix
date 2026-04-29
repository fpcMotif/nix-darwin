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

    (helpers.assertTest "${prefix}-has-jj-starship-package"
      (hasPackage "jj-starship" homeConfig.home.packages)
      "${prefix} Home Manager package list should include jj-starship")

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

    (helpers.assertTest "${prefix}-agent-skills-source-grill-me"
      (homeConfig.programs.agent-skills.sources ? grill-me)
      "${prefix} should configure grill-me skill source")

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
      (homeConfig.programs.agent-skills.targets.pi.dest == "$HOME/.pi/agent/skills")
      "${prefix} should configure the Oh My Pi skill target")
  ];

  darwinConfig = self.darwinConfigurations."Martins-Mac-mini".config;
  darwinHome = darwinConfig.home-manager.users.${user};

  darwinChecks = [
    (helpers.assertTest "darwin-Martins-Mac-mini-evaluates"
      (evalsOk self.darwinConfigurations."Martins-Mac-mini".system)
      "darwinConfigurations.Martins-Mac-mini.system should evaluate")

    (helpers.assertTest "darwin-primary-user"
      (darwinConfig.system.primaryUser == user)
      "Darwin primary user should match ${user}")

    (helpers.assertTest "darwin-zsh-enabled"
      (darwinConfig.programs.zsh.enable == true)
      "Darwin should enable zsh at the system level")

    (helpers.assertTest "darwin-starship-enabled"
      (darwinHome.programs.starship.enable == true)
      "Darwin Home Manager should enable the migrated Starship prompt")

    (helpers.assertTest "darwin-starship-jj-starship-jj-custom"
      (
        let
          jj = darwinHome.programs.starship.settings.custom.jj;
          shell = jj.shell;
        in
        lib.hasInfix "jj-starship" jj.when
          && lib.hasInfix "$output" jj.format
          && builtins.elem "--no-color" shell
          && builtins.elem "--jj-symbol" shell
          && builtins.elem "--no-git-id" shell
          && builtins.elem "--no-git-status" shell
      )
      "Darwin Starship config should expose a powerline jj-starship VCS module")

    (helpers.assertTest "darwin-starship-disables-built-in-git-branch"
      (darwinHome.programs.starship.settings.git_branch.disabled == true)
      "jj-starship should replace Starship's built-in git_branch module")

    (helpers.assertTest "darwin-brew-default-disabled"
      (darwinConfig.martin.brew.homebrew.enable == false)
      "Homebrew emergency scaffold should remain disabled by default")

    (helpers.assertTest "darwin-has-sourcegraph-amp"
      (hasPackage "sourcegraph-amp" darwinHome.home.packages)
      "Darwin Home Manager packages should include sourcegraph-amp")

    (helpers.assertTest "darwin-has-oh-my-pi"
      (hasPackage "oh-my-pi" darwinHome.home.packages)
      "Darwin Home Manager packages should include oh-my-pi")
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
  ]
  ++ (homeChecks "wsl" wslHome "/home/${user}")
  ++ (homeChecks "x230" x230Home "/home/${user}")
  ++ (homeChecks "vm-aarch64-utm" vmHome "/home/${user}");

in
helpers.testSuite "configurations-eval" (darwinChecks ++ nixosChecks)
