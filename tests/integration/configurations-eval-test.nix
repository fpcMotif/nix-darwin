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
#   * common packages (git) are present in home.packages
#   * migrated Home Manager program modules are enabled
#   * darwin-only agent packages are gated to darwin
#   * system-level zsh stays on (this IS owned by Nix, not unmanaged dotfiles)
#   * the martin.shell.search plane is on by default (^G chords, fzf-git-sh
#     packaged) and its Ghostty keybind veneer appears only on darwin
{ pkgs
, lib
, inputs
, evalScope ? "auto"
, darwinConfigurationInput ? null
, darwinDojjoConfigurationInput ? null
, x230ConfigurationInput ? null
, vmConfigurationInput ? null
, ...
}:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };
  guideCatalog = import ../../modules/home/agent-instructions/guides.nix { inherit lib pkgs; };
  guideTargets = guideCatalog.targets;

  user = "martinfan";
  selectedScope =
    if evalScope == "auto" then
      (if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "nixos")
    else evalScope;

  darwinConfiguration = if selectedScope == "darwin" then darwinConfigurationInput else null;
  darwinConfig = if darwinConfiguration != null then darwinConfiguration.config else null;
  darwinSystem = if darwinConfiguration != null then darwinConfiguration.system else null;
  darwinHome = if darwinConfig != null then darwinConfig.home-manager.users.${user} else null;
  x230Configuration = if selectedScope == "nixos" then x230ConfigurationInput else null;
  vmConfiguration = if selectedScope == "nixos" then vmConfigurationInput else null;
  x230Config = if x230Configuration != null then x230Configuration.config else null;
  vmConfig = if vmConfiguration != null then vmConfiguration.config else null;
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

  # The real host with the experimental backend selected (tests/default.nix).
  # Only the default host is built by `just switch`.
  darwinDojjo = if selectedScope == "darwin" then darwinDojjoConfigurationInput else null;
  darwinDojjoHome = darwinDojjo.config.home-manager.users.${user};

  # workspace-backend.nix alone, for platforms this host cannot evaluate in
  # full (see toplevelEvaluatesOnNative). Returns the failed assertion messages.
  backendAssertionFailures = system: backend:
    let
      evaluated = lib.evalModules {
        modules = [
          ../../modules/home/workspace-backend.nix
          {
            options.assertions = lib.mkOption {
              type = lib.types.listOf lib.types.unspecified;
              default = [ ];
            };
            config = {
              _module.args.pkgs = import inputs.nixpkgs {
                inherit system;
                overlays = [ (import ../../pkgs) ];
              };
              martin.development.workspaceBackend = backend;
            };
          }
        ];
      };
    in
    map (a: a.message) (builtins.filter (a: !a.assertion) evaluated.config.assertions);

  workspaceBackendChecks = [
    (helpers.assertTest "darwin-dojjo-evaluates"
      (evalsOk darwinDojjo.system)
      "darwinConfigurations.f with workspaceBackend = dojjo should evaluate")

    (helpers.assertTest "darwin-dojjo-replaces-worktrunk"
      (darwinDojjoHome.martin.development.workspaceBackend == "dojjo"
        && darwinDojjoHome.programs.worktrunk.enable == false
        && !(darwinDojjoHome.xdg.configFile ? "worktrunk/config.toml")
        && darwinDojjoHome.xdg.configFile ? "dojjo/config.toml"
        && hasPackage "dojjo-bin" darwinDojjoHome.home.packages
        && !(hasPackage "worktrunk" darwinDojjoHome.home.packages))
      "dojjo backend should install djo and its config.toml, and drop wt and its config.toml")

    (helpers.assertTest "darwin-dojjo-zsh-integration"
      (lib.hasInfix "-dojjo-init.zsh" darwinDojjoHome.programs.zsh.initContent
        && !(lib.hasInfix "-worktrunk-init.zsh" darwinDojjoHome.programs.zsh.initContent))
      "dojjo backend should source the build-rendered djo wrapper and completion, not wt's")

    (helpers.assertTest "darwin-dojjo-drops-worktrunk-markers"
      (!(darwinDojjoHome.home.file ? ".claude/hooks/worktrunk-marker.sh")
        && darwinDojjoHome.home.activation ? "claudeSettingsOwnership")
      "dojjo backend should stop installing the Worktrunk marker script and keep the settings reconciler")

    (helpers.assertTest "darwin-dojjo-agent-guidance"
      (lib.all
        (target:
          let guide = darwinDojjoHome.home.file.${target}.source.text;
          in lib.hasInfix "djo switch --create" guide && !(lib.hasInfix "wt switch" guide))
        [ ".claude/guidance/development.md" ".codex/guidance/development.md" ".config/agent-guidance/development.md" ])
      "dojjo backend should render dojjo guidance for every agent host")

    (helpers.assertTest "darwin-default-agent-guidance"
      (lib.hasInfix "wt switch --create" darwinHome.home.file.".claude/guidance/development.md".source.text)
      "the default backend should keep Worktrunk guidance")

    (helpers.assertTest "workspace-backend-dojjo-fails-clearly-on-linux"
      (
        let failures = backendAssertionFailures "x86_64-linux" "dojjo";
        in builtins.length failures == 1
          && lib.hasInfix "aarch64-darwin" (lib.head failures)
          && lib.hasInfix "x86_64-linux" (lib.head failures)
      )
      "selecting dojjo on Linux should fail evaluation with a message naming the supported platform")

    (helpers.assertTest "workspace-backend-assertion-passes-when-supported"
      (backendAssertionFailures "x86_64-linux" "worktrunk" == [ ]
        && backendAssertionFailures "aarch64-darwin" "dojjo" == [ ])
      "the platform assertion should pass for Worktrunk anywhere and dojjo on aarch64-darwin")
  ];

  # Standalone re-evaluation of modules/home/zsh.nix with martin.shell.viMode
  # toggled (see tests/lib/zsh-module-eval.nix): proves the escape hatch
  # restores today's emacs shape without paying for a second full-host
  # evaluation. The enabled-path assertions below still read the REAL host
  # configuration; these only cover the off/derivation side of the toggle.
  zshViOff = (import ../lib/zsh-module-eval.nix { inherit pkgs lib; }) { viMode = false; };
  zshViOn = (import ../lib/zsh-module-eval.nix { inherit pkgs lib; }) { };
  zshSearchOff = (import ../lib/zsh-module-eval.nix { inherit pkgs lib; }) { searchEnable = false; };
  zshDirJumpNull = (import ../lib/zsh-module-eval.nix { inherit pkgs lib; }) { dirJumpNull = true; };

  viModeToggleChecks = [
    (helpers.assertTest "home-zsh-vi-mode-off-default-keymap-emacs"
      (zshViOff.programs.zsh.defaultKeymap == "emacs")
      "Disabling martin.shell.viMode must restore the emacs default keymap")

    (helpers.assertTest "home-zsh-vi-mode-off-no-plugin"
      (!(lib.any (p: p.name == "zsh-vi-mode") zshViOff.programs.zsh.plugins))
      "Disabling martin.shell.viMode must drop the zsh-vi-mode plugin")

    (helpers.assertTest "home-zsh-vi-mode-off-no-zvm-wiring"
      (!(lib.hasInfix "ZVM_INIT_MODE" zshViOff.programs.zsh.initContent))
      "Disabling martin.shell.viMode must leave no ZVM_* wiring behind")

    (helpers.assertTest "home-zsh-vi-mode-on-native-keymap"
      (zshViOn.programs.zsh.defaultKeymap == "viins"
        && zshViOn.programs.zsh.plugins == [ ])
      "Default-evaluated module must land in viins with zero plugins (native Zsh vi mode)")
  ];

  # Same seam, second plane: martin.shell.search. Proves the toggle drops
  # every trace of the search machinery and that per-key nulls remove only
  # their own chord.
  searchToggleChecks = [
    (helpers.assertTest "home-zsh-search-off-no-widgets"
      (!(lib.hasInfix "martin-content-search" zshSearchOff.programs.zsh.initContent))
      "Disabling martin.shell.search must leave no content-search widgets behind")

    (helpers.assertTest "home-zsh-search-off-no-plugin-or-package"
      (!(lib.any (p: p.name == "fzf-git-sh") zshSearchOff.programs.zsh.plugins)
        && !(hasPackage "fzf-git-sh" (zshSearchOff.home.packages or [ ])))
      "Disabling martin.shell.search must drop fzf-git-sh from both plugins and home.packages")

    (helpers.assertTest "home-zsh-search-null-dirjump-chord-gone"
      (!(lib.hasInfix "'^Gd'" zshDirJumpNull.programs.zsh.initContent)
        && lib.hasInfix "'^Gf'" zshDirJumpNull.programs.zsh.initContent)
      "Setting martin.shell.search.keys.dirJump to null must remove only the ^Gd chord")

    (helpers.assertTest "home-zsh-search-default-widgets-present"
      (lib.hasInfix "martin-content-search" zshViOn.programs.zsh.initContent)
      "The default evaluation must include the search-plane widgets")
  ];

  # Modular shell evaluation: proves each optional module is independently removable
  # and that session/PATH remains invariant (issue #381 requirement).
  evalModularShell = mods: (import ../lib/zsh-module-eval.nix { inherit pkgs lib; })
    ({ includeSession = true; } // mods);

  shellAll = evalModularShell { includePrompt = true; };
  shellMinimal = evalModularShell { includeDirenv = false; includeFzf = false; includeZoxide = false; includePrompt = false; };
  shellNoPrompt = evalModularShell { includePrompt = false; };
  shellNoFzf = evalModularShell { includeFzf = false; };
  shellNoZoxide = evalModularShell { includeZoxide = false; };
  shellNoDirenv = evalModularShell { includeDirenv = false; };

  modularShellChecks = [
    (helpers.assertTest "modular-shell-minimal-zsh-works"
      (shellMinimal.programs.zsh.enable == true
        && lib.hasInfix "PROMPT='%F{cyan}%1~%f %# '" shellMinimal.programs.zsh.initContent)
      "Minimal shell without optional modules must enable zsh and have native fallback prompt")

    (helpers.assertTest "modular-shell-path-invariant-across-modules"
      (shellAll.home.sessionPath == shellMinimal.home.sessionPath
        && shellAll.home.sessionPath == shellNoPrompt.home.sessionPath
        && shellAll.home.sessionPath == shellNoFzf.home.sessionPath
        && shellAll.home.sessionPath == shellNoZoxide.home.sessionPath
        && shellAll.home.sessionPath == shellNoDirenv.home.sessionPath)
      "home.sessionPath must remain completely invariant whether optional modules are present or removed")

    (helpers.assertTest "modular-shell-delete-prompt-safe"
      (shellNoPrompt.programs.zsh.enable == true
        && (!(shellNoPrompt.programs ? starship) || shellNoPrompt.programs.starship.enable == false))
      "Removing prompt.nix leaves zsh working and disables starship")

    (helpers.assertTest "modular-shell-delete-fzf-safe"
      (shellNoFzf.programs.zsh.enable == true
        && (!(shellNoFzf.programs ? fzf) || shellNoFzf.programs.fzf.enable == false)
        && (!(lib.hasInfix "martin-content-search-widget" shellNoFzf.programs.zsh.initContent)))
      "Removing fzf.nix leaves zsh working, disables fzf, and omits fzf search widgets")

    (helpers.assertTest "modular-shell-delete-zoxide-safe"
      (shellNoZoxide.programs.zsh.enable == true
        && (!(shellNoZoxide.programs ? zoxide) || shellNoZoxide.programs.zoxide.enable == false)
        && (!(lib.hasInfix "martin-dir-jump-widget" shellNoZoxide.programs.zsh.initContent)))
      "Removing zoxide.nix leaves zsh working, disables zoxide, and omits zoxide search widget")
    (helpers.assertTest "modular-shell-delete-direnv-safe"
      (shellNoDirenv.programs.zsh.enable == true
        && (!(shellNoDirenv.programs ? direnv) || shellNoDirenv.programs.direnv.enable == false))
      "Removing direnv.nix leaves zsh working and disables direnv")
  ];
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

      (helpers.assertTest "${prefix}-has-starship-package"
        (hasHomePackage "starship")
        "${prefix} Home Manager package list should include starship")

      (helpers.assertTest "${prefix}-excludes-jj-starship-package"
        (!(hasHomePackage "jj-starship"))
        "${prefix} Home Manager package list should not include jj-starship")

      (helpers.assertTest "${prefix}-home-zsh-enabled"
        (homePrograms.zsh.enable == true)
        "${prefix} Home Manager should own zsh config")

      (helpers.assertTest "${prefix}-home-zsh-history-substring-disabled"
        (homePrograms.zsh.historySubstringSearch.enable == false)
        "${prefix} Home Manager should not enable zsh-history-substring-search -- Up/Down uses the native zle prefix widget instead")

      (helpers.assertTest "${prefix}-home-zsh-vi-mode-enabled"
        (homeConfig.martin.shell.viMode.enable == true)
        "${prefix} Home Manager should enable martin.shell.viMode (vi editing at the prompt)")

      (helpers.assertTest "${prefix}-home-zsh-vi-mode-default-keymap-viins"
        (homePrograms.zsh.defaultKeymap == "viins")
        "${prefix} Home Manager should land zsh in viins when vi mode is enabled")

      (helpers.assertTest "${prefix}-home-zsh-vi-mode-native-zero-plugins"
        (homePrograms.zsh.plugins == [ ])
        "${prefix} Home Manager should use native Zsh vi mode with zero third-party plugins")

      (helpers.assertTest "${prefix}-home-session-path-no-duplicates"
        (builtins.length (lib.unique homeData.sessionPath) == builtins.length homeData.sessionPath)
        "${prefix} home.sessionPath must contain no duplicate entries")

      (helpers.assertTest "${prefix}-home-session-path-tiers-order"
        (
          let
            p = homeData.sessionPath;
            userInstallersStart = lib.elemAt p (if prefix == "darwin" then 5 else 4);
          in
          (prefix == "darwin" -> (lib.head p == "$HOME/Library/Application Support/mbx/bin"))
          && (lib.elem "$HOME/.nix-profile/bin" p)
          && (userInstallersStart == "$HOME/.local/bin")
        )
        "${prefix} home.sessionPath must respect tier ordering: shims -> nixProfiles -> userInstallers")

      (helpers.assertTest "${prefix}-home-session-variables-editor"
        (homeData.sessionVariables.EDITOR == "nvim" && homeData.sessionVariables.VISUAL == "nvim")
        "${prefix} home.sessionVariables must set EDITOR and VISUAL to nvim")

      (helpers.assertTest "${prefix}-home-session-variables-pnpm-platform"
        (if prefix == "darwin" then
          homeData.sessionVariables.PNPM_HOME == "$HOME/Library/pnpm"
        else
          homeData.sessionVariables.PNPM_HOME == "$HOME/.local/share/pnpm")
        "${prefix} home.sessionVariables must set platform-correct PNPM_HOME")
      (helpers.assertTest "${prefix}-ghostty-opens-intended-shell"
        (homePrograms.zsh.enable == true
          && (prefix == "darwin" -> homeData.sessionVariables.SHELL == "/bin/zsh"))
        "${prefix} Ghostty opens intended login shell (zsh enabled, SHELL=/bin/zsh on Darwin)")

      (helpers.assertTest "${prefix}-tmux-opens-intended-shell"
        (
          let
            zshBin = builtins.unsafeDiscardStringContext "${pkgs.zsh}/bin/zsh";
            tmuxCfg = builtins.unsafeDiscardStringContext homePrograms.tmux.extraConfig;
          in
          homePrograms.tmux.shell == "${pkgs.zsh}/bin/zsh"
          && lib.hasInfix "default-command \"${zshBin} -l\"" tmuxCfg
        )
        "${prefix} tmux must explicitly configure zsh as default shell and login default-command")
      (helpers.assertTest "${prefix}-direnv-activates-projects"
        (homePrograms.direnv.enable == true
          && homePrograms.direnv.nix-direnv.enable == true
          && homePrograms.direnv.enableZshIntegration == true)
        "${prefix} direnv and nix-direnv with zsh integration must be enabled")

      (helpers.assertTest "${prefix}-agent-noninteractive-receives-environment"
        (homeData.sessionVariables ? EDITOR
          && homeData.sessionVariables ? BUN_INSTALL
          && homeData.sessionVariables ? CLAUDE_CODE_EFFORT_LEVEL
          && homeData.sessionVariables ? CDPATH)
        "${prefix} non-interactive and agent shells receive session environment variables")

      (helpers.assertTest "${prefix}-home-zoxide-enabled"
        (homePrograms.zoxide.enable == true)
        "${prefix} Home Manager should enable zoxide integration")

      (helpers.assertTest "${prefix}-home-git-enabled"
        (homePrograms.git.enable == true)
        "${prefix} Home Manager should own git config")

      (helpers.assertTest "${prefix}-home-jujutsu-enabled"
        (homePrograms.jujutsu.enable == true)
        "${prefix} Home Manager should own jj config")

      (helpers.assertTest "${prefix}-home-worktrunk-config"
        (homeConfig.martin.development.workspaceBackend == "worktrunk"
          && homePrograms.worktrunk.enable == true
          && homeXdg.configFile ? "worktrunk/config.toml"
          && homePrograms.worktrunk.settings.skip-shell-integration-prompt == true
          && homePrograms.worktrunk.settings.worktree-path == "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}")
        "${prefix} Worktrunk should stay the default backend, own config.toml, and pre-answer the prompt that writes it")

      (helpers.assertTest "${prefix}-default-backend-excludes-dojjo"
        (!(homeXdg.configFile ? "dojjo/config.toml")
          && !(hasHomePackage "dojjo-bin")
          && lib.hasInfix "-worktrunk-init.zsh" homePrograms.zsh.initContent
          && !(lib.hasInfix "-dojjo-init.zsh" homePrograms.zsh.initContent))
        "${prefix} the default backend should source only the Worktrunk wrapper and install no dojjo")

      (helpers.assertTest "${prefix}-claude-settings-ownership-activation"
        (homeData.file ? ".claude/hooks/worktrunk-marker.sh"
          && homeActivation ? "claudeSettingsOwnership"
          && builtins.elem "writeBoundary" homeActivation.claudeSettingsOwnership.after
          && builtins.all
          (name: !(builtins.hasAttr name homeActivation))
          [
            "claudeSkillSurfaceDedup"
            "claudeSettingsSeed"
            "claudePermissionsAssert"
            "claudeDisableGlobalMcpPlugins"
            "claudeMemorySettingsAssert"
            "claudeWorktreeSettingsAssert"
            "claudeHooksAssert"
          ])
        "${prefix} should use one post-writeBoundary Claude settings reconciliation activation")

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
          builtins.elem "grill-with-docs" enabled
          && !(builtins.hasAttr "grill-with-docs" explicit)
          && !(builtins.elem "grill-me" enabled)
          && !(builtins.hasAttr "grill-me" explicit)
        )
        "${prefix} should carry grill-with-docs via plain bucket auto-discovery (the Karpathy fork is retired) and still refuse grill-me")

      (helpers.assertTest "${prefix}-agent-skills-removes-git-workflow"
        (
          let cfg = homePrograms.agent-skills;
          in
          !(builtins.hasAttr "git-workflow" cfg.catalog)
          && !(builtins.elem "git-workflow" cfg.skills.enable)
          && !(builtins.hasAttr "git-workflow" cfg.skills.explicit)
        )
        "${prefix} should remove git-workflow from discovery and the active skill bundle")

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


      (helpers.assertTest "${prefix}-claude-plugin-skill-prune-wired"
        (
          let activation = homeActivation.claudePrunePluginSkills.data;
          in
          lib.hasInfix "grill-me" activation
          && !(lib.hasInfix "setup-matt-pocock-skills" activation)
          && lib.hasInfix ".claude-plugin/plugin.json" activation
        )
        "${prefix} should prune grill-me out of the cached mattpocock-skills plugin manifest — skillOverrides cannot reach a plugin skill — while leaving setup-matt-pocock-skills reachable")

      (helpers.assertTest "${prefix}-agent-skills-full-set-on-non-claude-targets"
        (
          let cfg = homePrograms.agent-skills;
          in
          builtins.elem "grilling" cfg.skills.enable
          && builtins.elem "grill-with-docs" cfg.skills.enable
          && builtins.elem "improve-codebase-architecture" cfg.skills.enable
          && cfg.targets.agents.enable
          && cfg.targets.codex.enable
        )
        "${prefix} must keep plugin-duplicated skills IN the bundle — Codex/Droid/OpenCode/Crush have no plugin system and read the picker dirs")

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
        (!(homePrograms.agent-skills.targets ? factory))
        "${prefix} must not link skills into ~/.factory/skills — droid also scans ~/.agents/skills and flags every skill as a Duplicate skill diagnostic")

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

      (helpers.assertTest "${prefix}-lsp-declarative-codex-and-safe-desktop"
        (
          let
            desktopOk =
              if prefix == "darwin" then
                let desktop = homeActivation.claudeDesktopMcpScaffold.data;
                in
                lib.hasInfix "DRY_RUN" desktop
                && !(lib.hasInfix "exit 0" desktop)
              else
                !(homeActivation ? claudeDesktopMcpScaffold);
          in
          !(homeActivation ? codexLspConfig)
          && desktopOk
        )
        "${prefix} Codex LSP must have no activation writer; desktop scaffolding must respect dry runs")

      (helpers.assertTest "${prefix}-agent-guide-files"
        (prefix != "darwin" || lib.all
          (path: builtins.hasAttr path homeData.file && !homeData.file.${path}.force)
          ([
            ".codex/fast.config.toml"
            ".codex/fast-low.config.toml"
            ".codex/plan.config.toml"
            ".codex/deep.config.toml"
            ".codex/guidance/setup.md"
            ".config/agent-routing/omp.yml"
            ".config/agent-routing/omp-economy.yml"
            ".config/agent-routing/README.md"
          ] ++ guideTargets))
        "${prefix} catalog guides and agent profiles must use non-forced Home Manager files")

      (helpers.assertTest "${prefix}-codex-user-config-writable"
        (prefix != "darwin" ||
          (!(builtins.hasAttr ".codex/config.toml" homeData.file)
            && homeActivation ? ensureWritableCodexConfig
            && lib.hasInfix "replace_store_link" homeActivation.ensureWritableCodexConfig.data
            && lib.hasInfix "migrate legacy full config" homeActivation.ensureWritableCodexConfig.data
            && lib.hasInfix "DRY_RUN" homeActivation.ensureWritableCodexConfig.data))
        "${prefix} Codex user config must remain writable and migrate old Nix-store links safely")

      (helpers.assertTest "${prefix}-agent-runtime-state-unmanaged"
        (lib.all (path: !(builtins.hasAttr path homeData.file))
          [
            ".codex/auth.json"
            ".codex/plugins"
            ".claude/plugins"
            ".omp/agent/config.yml"
            ".omp/agent/auth.json"
          ])
        "${prefix} credentials, native plugin caches, and OMP runtime model state must remain outside the Nix store")

      (helpers.assertTest "${prefix}-surge-skill-single-writer"
        (!(homeActivation ? surgeAgentSkillSymlinks))
        "${prefix} Surge skill activation must not replace the declarative personal skill symlinks")

      (helpers.assertTest "${prefix}-home-zsh-search-baseline"
        (homeConfig.martin.shell.search.enable == true
          && homeConfig.martin.shell.search.prefix == "^G"
          && homeConfig.martin.shell.search.keys.contentSearch == "f"
          && homeConfig.martin.shell.search.keys.dirJump == "d"
          && homeConfig.martin.shell.search.keys.processKill == "k")
        "${prefix} Home Manager should enable martin.shell.search with the documented ^G chord set")

      (helpers.assertTest "${prefix}-home-fzf-git-sh-packaged"
        (hasHomePackage "fzf-git-sh")
        "${prefix} Home Manager should package fzf-git-sh for the search plane")

      (helpers.assertTest "${prefix}-home-ghostty-keybinds-unique"
        (
          let
            keybindTriggers = map
              (line: lib.head (lib.splitString "=" (lib.removePrefix "keybind = " line)))
              (lib.filter (lib.hasPrefix "keybind = ")
                (lib.splitString "\n" homeXdg.configFile."ghostty/config".text));
          in
          (builtins.length (lib.unique keybindTriggers)) == builtins.length keybindTriggers
        )
        "${prefix} Ghostty keybind triggers must be globally unique -- a future group collision must fail the build, not steal a chord silently")

      (helpers.assertTest "${prefix}-home-ghostty-search-veneer"
        (
          let text = homeXdg.configFile."ghostty/config".text;
          in if prefix == "darwin" then
            lib.all (t: lib.hasInfix "keybind = ${t}=text:" text)
              [ "cmd+f" "cmd+j" "cmd+shift+k" "cmd+b" ]
          else
            !(lib.any (t: lib.hasInfix "keybind = ${t}=text:" text)
              [ "cmd+f" "cmd+j" "cmd+shift+k" "cmd+b" ])
        )
        "${prefix} Ghostty config must carry the search keybind veneer exactly on darwin and nowhere else")
    ];

  darwinChecks = [
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
          && lib.hasInfix "[lsp.servers.tsgo]" codexDefaults
          && lib.hasInfix "[mcp_servers.fff]" codexDefaults
          && lib.hasInfix ''PI_PLAN_MODEL = "openai-codex/gpt-6-astra:xhigh"'' codexDefaults
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

    # BetterMouse left Nix on 2026-08-17 and BetterDisplay on 2026-08-19, for
    # the same reason: both ship Sparkle, which self-updated the writable
    # /Applications copy this repo installed, so the pin silently stopped
    # describing what was on disk. Both are GUI-managed now, and the whole
    # `martin.mouseDisplay` -> `martin.display` module is gone. See
    # docs/adr/0011-bettermouse-is-gui-managed-not-nix-managed.md and
    # docs/adr/0012-betterdisplay-is-gui-managed-not-nix-managed.md.
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

    # skhd is deliberately OFF on this host as of 2026-07-19: its CGEventTap
    # fights BetterMouse's, and the mouse layer won that argument. Everything
    # under `services.skhd` -- the launchd agent, the package, and the rendered
    # `skhdConfig` -- is gated behind `mkIf cfg.enable` in modules/darwin/skhd.nix,
    # so there is no config text left to assert on. The old
    # darwin-skhd-finder-cut-mode / darwin-skhd-finder-native-move assertions
    # were retired with the hotkey layer; modules/darwin/skhd.nix and the
    # `martin.skhd.extraConfig` block in hosts/darwin/default.nix are kept intact
    # so re-enabling stays a one-line flip. Assert the OFF state so that flip has
    # to arrive as a deliberate test change rather than silently reintroducing
    # the tap conflict.
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
      "Darwin Home Manager packages should include Crush from Charm NUR")

    (helpers.assertTest "darwin-has-oh-my-pi"
      (hasPackage "oh-my-pi" darwinHome.home.packages)
      "Darwin Home Manager packages should include oh-my-pi")


    (helpers.assertTest "darwin-has-uv"
      (hasPackage "uv" darwinHome.home.packages)
      "Darwin Home Manager packages should include uv for Python package management")
    (helpers.assertTest "darwin-registers-drafts-mcp"
      (darwinHome.home.activation ? claudeMcpDrafts)
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
  ] ++ viModeToggleChecks ++ searchToggleChecks ++ modularShellChecks ++ workspaceBackendChecks
  ++ (homeChecks "darwin" darwinHome "/Users/${user}");

  nixosChecks = [
    (toplevelEvaluatesOnNative "x230" "x86_64-linux" x230Config)
    (toplevelEvaluatesOnNative "vm-aarch64-utm" "aarch64-linux" vmConfig)

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
      (!(hasPackage "sourcegraph-amp" x230Home.home.packages))
      "Linux Home Manager packages should not include Darwin-only agent packages")

    (helpers.assertTest "linux-excludes-drafts-mcp-activation"
      (!(x230Home.home.activation ? claudeMcpDrafts))
      "Linux Home Manager should not force the Darwin-only Drafts MCP server")

    (helpers.assertTest "linux-zed-editor-disabled"
      (
        x230Home.programs.zed-editor.enable == false
          && vmHome.programs.zed-editor.enable == false
      )
      "Linux Home Manager should leave programs.zed-editor off — zed-nightly-bin is Darwin-only")

    (helpers.assertTest "linux-excludes-zed-nightly-bin-package"
      (
        !(hasPackage "zed-nightly-bin" x230Home.home.packages)
          && !(hasPackage "zed-nightly-bin" vmHome.home.packages)
      )
      "Linux Home Manager package lists must never include the Darwin-only zed-nightly-bin")
  ]
  ++ viModeToggleChecks
  ++ searchToggleChecks
  ++ (homeChecks "x230" x230Home "/home/${user}")
  ++ (homeChecks "vm-aarch64-utm" vmHome "/home/${user}");

  selectedChecks = if selectedScope == "darwin" then darwinChecks else
  if selectedScope == "nixos" then nixosChecks
  else darwinChecks ++ nixosChecks;
in
helpers.testSuite "configurations-eval" selectedChecks
