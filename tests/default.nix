# Test entry point for the flake.
#
# Returns an attribute set of derivations (one per test). Each test either:
#   * builds successfully -> the test passes
#   * fails to build      -> the test fails with an explanation
#
# Wired into the flake via `checks.<system>` so `nix flake check` runs them.
{ inputs, system, self }:

let
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ (import ../pkgs) ];
    config.allowUnfree = true;
  };
  lib = pkgs.lib;

  callTest = path: extraArgs: import path ({ inherit inputs system pkgs lib self; } // extraArgs);

  # Host "f" with the experimental workspace backend, the way its user would
  # select it. Evaluated once and shared by every check that reads it.
  darwinDojjo = self.darwinConfigurations."f".extendModules {
    modules = [{ home-manager.users.martinfan.martin.development.workspaceBackend = "dojjo"; }];
  };
in
{
  smoke = pkgs.runCommand "smoke-test" { } ''
    echo "PASS test infrastructure OK on ${system}"
    touch $out
  '';

  # Unit tests
  unit-mksystem = callTest ./unit/mksystem-test.nix { };
  unit-overlay = callTest ./unit/overlay-test.nix { };
  unit-format = callTest ./unit/format-test.nix { };
  unit-auto-update = pkgs.runCommand "unit-auto-update" { nativeBuildInputs = [ pkgs.bash pkgs.gnugrep pkgs.perl ]; } ''
    bash ${./unit/auto-update-test.sh} \
      ${../scripts/lib/auto-update.sh} \
      ${../modules/darwin/auto-switch.nix} \
      ${../pkgs} \
      ${../scripts} \
      ${../.github}
    touch $out
  '';
  unit-justfile = pkgs.runCommand "unit-justfile" { nativeBuildInputs = [ pkgs.bash pkgs.gnugrep ]; } ''
    bash ${./unit/justfile-test.sh} ${../justfile}
    touch $out
  '';
  unit-rolling-pins = pkgs.runCommand "unit-rolling-pins" { nativeBuildInputs = [ pkgs.bash pkgs.gnugrep ]; } ''
    bash ${./unit/rolling-pins-test.sh} ${../pkgs} ${../scripts}
    touch $out
  '';
  unit-agent-guides =
    let
      guideCatalog = import ../modules/home/agent-instructions/guides.nix { inherit lib pkgs; };
      hosts = guideCatalog.hosts;
      dojjoHosts = (import ../modules/home/agent-instructions/guides.nix {
        inherit lib pkgs;
        workspaceBackend = "dojjo";
      }).hosts;
      # Each backend's guide names only its own isolation commands.
      workspaceGuideFits = backendHosts: required: forbidden:
        lib.all
          (host:
            lib.all (text: lib.hasInfix text (contentForHost host)) required
            && lib.all (text: !(lib.hasInfix text (contentForHost host))) forbidden)
          (lib.attrValues backendHosts);
      hasWord = word: text:
        lib.any
          (line:
            builtins.match ".*(^|[^A-Za-z0-9_])${word}($|[^A-Za-z0-9_]).*" line != null)
          (lib.splitString "\n" text);
      contentForHost = host:
        lib.concatStringsSep "\n" (map (guide: guide.content)
          ([ host.startup ] ++ lib.optional (host ? development) host.development));
      count = marker: text: builtins.length (lib.splitString marker text) - 1;
      requiredSections = [
        "## Working contract"
        "## Completion"
        "## Command routing"
        "## Code search"
        "## Python"
        "## Version control"
        "## Parallel checkouts"
        "## Code quality"
        "## Writing"
      ];
      onceSections = [
        "## Working contract"
        "## Code quality"
        "## Testing"
        "## Command routing"
        "## Waiting and background work"
        "## Parallel checkouts"
      ];
      bannedTerms = [ "gemini" "deepwiki" "mgrep" "lazygit" "deep-research" "chezmoi" ];
      requiredTools = [ "fd" "rg" "bat" "eza" "dust" "procs" "btm" "ax" "delta" "hyperfine" ];
      noModelCache = text: lib.all (term: !(lib.hasInfix term text)) [
        "gpt-"
        "Gemini"
        "Astra"
        "Sol"
        "Terra"
        "Luna"
      ];
      checkHost = name: host:
        let
          content = contentForHost host;
          links = builtins.filter
            (guide: guide.target != host.startup.target)
            host.guides;
          tools = requiredTools ++ lib.optional (name == "claude") "fff";
        in
        assert lib.all (section: lib.hasInfix section content) requiredSections;
        assert lib.all (section: count section content == 1) onceSections;
        assert lib.all
          (term: !(lib.hasInfix (lib.toLower term) (lib.toLower content)))
          bannedTerms;
        assert noModelCache content;
        assert lib.all (tool: hasWord tool content) tools;
        assert lib.all
          (guide: lib.hasInfix "~/${guide.target}" host.startup.content)
          links;
        true;
      hostChecks = lib.mapAttrsToList checkHost hosts;
    in
    assert !(hasWord "bat" "batch");
    assert lib.all (passed: passed) hostChecks;
    assert workspaceGuideFits hosts [ "wt switch --create" ] [ "djo" ];
    assert workspaceGuideFits dojjoHosts
      [ "djo switch --create" "jj workspace forget" "never a Git worktree" ]
      [ "wt switch" "wt remove" ];
    assert lib.hasInfix "The document is done when" hosts.claude.humanDocuments.content;
    pkgs.runCommand "unit-agent-guides" { } ''
      touch $out
    '';
  unit-shell-guard = pkgs.runCommand "unit-shell-guard" { nativeBuildInputs = [ pkgs.bash pkgs.jq pkgs.gnugrep pkgs.gnused pkgs.gawk ]; } ''
    bash ${../modules/home/claude/hooks/shell-guard-test.sh} \
      ${../modules/home/claude/hooks/shell-guard.sh}
    touch $out
  '';
  unit-edit-batch-nudge = pkgs.runCommand "unit-edit-batch-nudge" { nativeBuildInputs = [ pkgs.bash pkgs.jq pkgs.gnused pkgs.coreutils ]; } ''
    bash ${../modules/home/claude/hooks/edit-batch-nudge-test.sh} \
      ${../modules/home/claude/hooks/edit-batch-nudge.sh}
    touch $out
  '';
  unit-claude-settings-ownership = callTest ./unit/claude-settings-ownership-test.nix { };

  # Drives wt and djo through create, switch, list, remove, hooks, and a
  # backend switch in disposable repositories. It uses the config files and Zsh
  # lines host "f" ships under each backend, so it runs where "f" builds.
  unit-workspace-backend-lifecycle =
    if system == "aarch64-darwin" then
      let
        user = "martinfan";
        worktrunkHome = self.darwinConfigurations.f.config.home-manager.users.${user};
        dojjoHome = darwinDojjo.config.home-manager.users.${user};
        zshSourceLines = home: marker: pkgs.writeText "${marker}-lines"
          (lib.concatMapStrings (line: line + "\n")
            (builtins.filter (lib.hasInfix marker) (lib.splitString "\n" home.programs.zsh.initContent)));
      in
      pkgs.runCommand "unit-workspace-backend-lifecycle"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.git
            pkgs.jq
            pkgs.zsh
            worktrunkHome.programs.jujutsu.package
            worktrunkHome.programs.worktrunk.package
            pkgs.martin.dojjo-bin
          ];
        }
        ''
          bash ${./unit/workspace-backend-lifecycle-test.sh} \
            ${worktrunkHome.xdg.configFile."worktrunk/config.toml".source} \
            ${zshSourceLines worktrunkHome "-worktrunk-init.zsh"} \
            ${dojjoHome.xdg.configFile."dojjo/config.toml".source} \
            ${zshSourceLines dojjoHome "-dojjo-init.zsh"}
          touch $out
        ''
    else
      pkgs.runCommand "unit-workspace-backend-lifecycle-skipped" { } ''
        echo "Skipping the workspace-backend lifecycle test on ${system}; host f is aarch64-darwin"
        touch $out
      '';
  unit-skill-router = callTest ./unit/skill-router-test.nix { };
  unit-skill-hygiene = callTest ./unit/skill-hygiene-test.nix { };
  unit-pstack-hygiene = callTest ./unit/pstack-hygiene-test.nix { };
  unit-ai-model-routing =
    let
      routing = import ../modules/shared/agent-model-routing.nix { inherit lib; };
      policy = pkgs.writeText "agent-model-routing-test.json" (builtins.toJSON routing.policy);
      omp = routing.adapters.omp;
      roleModel = role: omp.normal.modelRoles.${role};
      agentModel = agent:
        let role = lib.removePrefix "@" omp.normal.task.agentModelOverrides.${agent};
        in roleModel role;
      fallbackChains = omp.normal.retry.fallbackChains;
      economy = omp.economy;
      serializedAdapters = builtins.toJSON routing.adapters;
      routingPython = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.pyyaml ]);
    in
    assert agentModel "scout" == routing.selector "search";
    assert agentModel "explore" == routing.selector "search";
    assert agentModel "librarian" == routing.selector "search";
    assert agentModel "reviewer" == routing.selector "check";
    assert agentModel "security-reviewer" == routing.selector "check";
    assert agentModel "task" == routing.selector "general";
    assert agentModel "plan" == routing.selector "plan";
    assert fallbackChains.${routing.bareSelector "general"} == [ (routing.bareSelector "economy") ];
    assert fallbackChains.${routing.bareSelector "search"} == [ ];
    assert fallbackChains.${routing.bareSelector "economy"} == [ ];
    assert lib.all (lib.hasPrefix "openai-codex/") (lib.attrValues omp.normal.modelRoles);
    assert lib.all
      (model:
        lib.hasPrefix "openai-codex/gpt-6-" model
        || model == "google-antigravity/*"
      )
      omp.normal.enabledModels;
    assert lib.elem "google-antigravity/*" omp.normal.enabledModels;
    assert lib.all (model: lib.hasInfix model serializedAdapters) [
      "gpt-6-astra"
      "gpt-6-sol"
      "gpt-6-luna"
    ];
    assert economy.modelRoles.default == routing.selector "economy";
    assert economy.modelRoles.reviewer == routing.selector "check";
    assert economy.modelRoles.plan == routing.selector "plan";
    assert economy.task.agentModelOverrides == omp.normal.task.agentModelOverrides;
    assert economy.retry == omp.normal.retry;
    assert routing.adapters.codex.profiles.fast.model == routing.modelId "search";
    assert routing.adapters.codex.profiles.plan.model == routing.modelId "plan";
    assert !(lib.hasInfix "gpt-5." serializedAdapters);
    pkgs.runCommand "unit-ai-model-routing" { } ''
      ${routingPython}/bin/python3 ${./unit/ai-model-routing-test.py} \
        ${../modules/home/ai-model-routing.py} ${policy}
      touch $out
    '';

  # Tier-1 hermetic check for martin.shell.viMode + martin.shell.search:
  # assembles the zshrc in home-manager's real section order, loads it in a
  # sandboxed zsh, and asserts on the post-load keymap tables -- ^R/^T/alt-c
  # fzf widgets in BOTH viins and vicmd, prefix-history Up/Down, fn-Delete,
  # Home/End/PgUp/PgDn, the keepEmacsKeys set in viins, v -> edit-command-line
  # in vicmd (#328); plus the ^G search plane -- repo chords, upstream ctrl
  # chords, prefix purity, per-key nulls, full disablement (#329). Three
  # scenarios run against three independently evaluated initContents.
  unit-zsh-vi-mode =
    let
      zshEval = overrides: (import ./lib/zsh-module-eval.nix { inherit pkgs lib; }) overrides;
      mkInit = name: overrides:
        pkgs.writeText "unit-zsh-vi-mode-initContent-${name}"
          (zshEval overrides).programs.zsh.initContent;
      run = scenario: initFile: ''
        SCENARIO=${scenario} bash ${./unit/zsh-vi-mode-test.sh} ${initFile} ${pkgs.fzf}
      '';
    in
    pkgs.runCommand "unit-zsh-vi-mode"
      {
        nativeBuildInputs = [ pkgs.bash pkgs.zsh pkgs.gnugrep ];
      }
      ''
        ${run "default" (mkInit "default" { })}
        ${run "null-dirjump" (mkInit "null-dirjump" { dirJumpNull = true; })}
        ${run "off" (mkInit "off" { searchEnable = false; })}
        touch $out
      '';

  # Integration tests
  integration-configurations-eval =
    if pkgs.stdenv.hostPlatform.isDarwin then
      callTest ./integration/configurations-eval-test.nix
        {
          evalScope = "darwin";
          darwinConfigurationInput = self.darwinConfigurations."f";
          darwinDojjoConfigurationInput = darwinDojjo;
        }
    else
      callTest ./integration/configurations-eval-test.nix {
        evalScope = "nixos";
        x230ConfigurationInput = self.nixosConfigurations.x230;
        vmConfigurationInput = self.nixosConfigurations.vm-aarch64-utm;
      };

  # Linux-only: the shared Home Manager profile must not leak macOS paths or
  # tools into the Linux hosts. Evaluating the Linux configs requires a Linux
  # builder (agent-skills resolves its bundle via import-from-derivation), so
  # this is a no-op skip on Darwin; CI runs it on the x86_64-linux builder.
  integration-home-linux-purity =
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.runCommand "integration-home-linux-purity-skipped" { } ''
        echo "Skipping Linux-only home purity test on ${system}"
        touch $out
      ''
    else
      callTest ./integration/home-linux-purity-test.nix {
        x230ConfigurationInput = self.nixosConfigurations.x230;
        vmConfigurationInput = self.nixosConfigurations.vm-aarch64-utm;
      };

  # Darwin-only: exact-value lock-in for the macOS settings host "f" commits to.
  # macOS settings have no meaning on the NixOS hosts, so this is a no-op skip
  # off-darwin (the CI matrix still runs it on its native macOS builder).
  integration-darwin-settings =
    if pkgs.stdenv.hostPlatform.isDarwin then
      callTest ./integration/darwin-settings-test.nix
        {
          darwinConfigurationInput = self.darwinConfigurations."f";
        }
    else
      pkgs.runCommand "integration-darwin-settings-skipped" { } ''
        echo "Skipping darwin-only macOS settings test on ${system}"
        touch $out
      '';


  smoke-build-oh-my-pi = pkgs.runCommand "smoke-build-oh-my-pi" { } (
    if pkgs.stdenv.hostPlatform.isDarwin then ''
      echo "Building oh-my-pi as a Darwin smoke test..."
      test -x ${pkgs.martin.oh-my-pi}/bin/omp
      touch $out
    '' else ''
      echo "Skipping Darwin-only smoke test on this platform"
      touch $out
    ''
  );

  smoke-build-toolchain = pkgs.runCommand "smoke-build-toolchain" { } (
    ''
      echo "Checking required Nix-only dotfiles toolchain commands..."
      ${lib.getExe pkgs.prek} --version
      ${lib.getExe pkgs.oxlint} --version
      ${lib.getExe pkgs.oxfmt} --version
      ${lib.getExe pkgs.tsgolint} --help >/dev/null
      ${lib.getExe pkgs.typescript} --version
      ${lib.getExe pkgs.uv} --version
      ${lib.getExe pkgs.ruff} --version
    ''
    # bun is shipped as the canary prebuilt (aarch64-darwin only), so validate
    # the binary that is actually installed rather than stock nixpkgs `bun`.
    + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      ${lib.getExe pkgs.martin.bun-canary-bin} --version
      test -L ${pkgs.martin.bun-canary-bin}/bin/bunx
    ''
    + ''
      touch $out
    ''
  );
}
