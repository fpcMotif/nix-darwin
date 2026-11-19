ctx:

let
  inherit (ctx) helpers lib user guideTargets;
in
prefix: homeConfig: expectedHomeDirectory:
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
        # The configuration's own zsh: the test's pkgs can be another
        # system, as when the x86_64-linux checks inspect the aarch64 VM.
        zshBin = builtins.unsafeDiscardStringContext "${homePrograms.zsh.package}/bin/zsh";
        tmuxCfg = builtins.unsafeDiscardStringContext homePrograms.tmux.extraConfig;
      in
      homePrograms.tmux.shell == zshBin
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
    (lib.all
      (path: builtins.hasAttr path homeData.file && !homeData.file.${path}.force)
      (guideTargets ++ lib.optionals (prefix == "darwin") [
        ".codex/fast.config.toml"
        ".codex/fast-low.config.toml"
        ".codex/plan.config.toml"
        ".codex/deep.config.toml"
        ".config/agent-routing/omp.yml"
        ".config/agent-routing/omp-economy.yml"
        ".config/agent-routing/README.md"
      ]))
    "${prefix} catalog guides and agent profiles must use non-forced Home Manager files")

  (helpers.assertTest "${prefix}-agent-guide-backup"
    (lib.all
      (path: lib.hasInfix (lib.escapeShellArg path) homeActivation.backupAgentInstructions.data)
      (guideTargets ++ [
        ".codex/guidance/setup.md"
        ".claude/search-routing.md"
        ".claude/references/search-routing-examples.md"
        ".claude/search-eval.md"
      ]))
    "${prefix} must archive every catalog guide, extras included, before Home Manager links it")

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
]
