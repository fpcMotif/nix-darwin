{ inputs, system, self }:

let
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ (import ../pkgs) ];
    config.allowUnfree = true;
  };
  inherit (pkgs) lib;

  callTest = path: extraArgs: import path ({ inherit inputs system pkgs lib self; } // extraArgs);

  shellTest = name: { script, inputs, args ? [ ] }:
    pkgs.runCommand name { nativeBuildInputs = [ pkgs.bash ] ++ inputs; } ''
      bash ${script} ${lib.concatMapStringsSep " " (arg: "${arg}") args}
      touch $out
    '';

  onlyOn = platform: name: test:
    if (platform == "darwin") == pkgs.stdenv.hostPlatform.isDarwin then test
    else
      pkgs.runCommand "${name}-skipped" { } ''
        echo "Skipping ${platform}-only ${name} on ${system}"
        touch $out
      '';

  # Host "f" with the experimental workspace backend, the way its user would
  # select it. Evaluated once and shared by every check that reads it.
  darwinDojjo = self.darwinConfigurations."f".extendModules {
    modules = [{ home-manager.users.martinfan.martin.development.workspaceBackend = "dojjo"; }];
  };

  readmeTestNames = lib.concatMap
    (line:
      let row = builtins.match "\\| `([a-z0-9-]+)`.*" line;
      in if row == null then [ ] else row)
    (lib.splitString "\n" (builtins.readFile ./README.md));
in
lib.fix (checks: {
  unit-tests-readme =
    let
      registered = builtins.attrNames checks;
      missing = lib.subtractLists readmeTestNames registered;
      unknown = lib.subtractLists registered readmeTestNames;
    in
    pkgs.runCommand "unit-tests-readme" { } (
      if missing == [ ] && unknown == [ ] then "touch $out"
      else ''
        echo "tests/README.md table is missing: ${toString missing}" >&2
        echo "tests/README.md table names unregistered checks: ${toString unknown}" >&2
        exit 1
      ''
    );

  smoke = pkgs.runCommand "smoke-test" { } ''
    echo "PASS test infrastructure OK on ${system}"
    touch $out
  '';

  # Unit tests
  unit-mksystem = callTest ./unit/mksystem-test.nix { };
  unit-overlay = callTest ./unit/overlay-test.nix { };
  unit-format = callTest ./unit/format-test.nix { };
  unit-auto-update = shellTest "unit-auto-update" {
    script = ./unit/auto-update-test.sh;
    inputs = [ pkgs.gnugrep pkgs.jq pkgs.perl ];
    args = [ ../scripts/lib/auto-update.sh ../modules/darwin/auto-switch.nix ../pkgs ../scripts ../.github ];
  };
  unit-justfile = shellTest "unit-justfile" {
    script = ./unit/justfile-test.sh;
    inputs = [ pkgs.gnugrep pkgs.gawk ];
    args = [ ../justfile ];
  };
  unit-build-workflow = shellTest "unit-build-workflow" {
    script = ./unit/build-workflow-test.sh;
    inputs = [ pkgs.gnugrep ];
    args = [ ../.github/workflows/build.yml ];
  };
  unit-rolling-pins = shellTest "unit-rolling-pins" {
    script = ./unit/rolling-pins-test.sh;
    inputs = [ pkgs.gnugrep ];
    args = [ ../pkgs ../scripts ];
  };

  # Current-state integrity for the maintained documents: file-level checks
  # fast enough to run on every change.
  unit-adr-files = shellTest "unit-adr-files" {
    script = ./unit/adr-files-test.sh;
    inputs = [ pkgs.findutils ];
    args = [ ../docs/adr ];
  };
  unit-adr-numbers = shellTest "unit-adr-numbers" {
    script = ./unit/adr-numbers-test.sh;
    inputs = [ pkgs.findutils pkgs.gnugrep ];
    args = [ ../docs/adr ];
  };
  # Link targets can sit anywhere in the repo, so this one reads the whole
  # flake source.
  unit-doc-links = shellTest "unit-doc-links" {
    script = ./unit/doc-links-test.sh;
    inputs = [ pkgs.findutils pkgs.gawk ];
    args = [ self ];
  };
  unit-doc-checks-fixtures = shellTest "unit-doc-checks-fixtures" {
    script = ./unit/doc-checks-fixtures-test.sh;
    inputs = [ pkgs.findutils pkgs.gnugrep pkgs.gawk ];
    args = [ ./unit/adr-files-test.sh ./unit/adr-numbers-test.sh ./unit/doc-links-test.sh ];
  };
  unit-agent-guides =
    let
      docLockGuide = ../modules/home/doc-lock/guide.md;
      guideHosts = startupSections: workspaceGuide: (import ../modules/home/agent-instructions/guides.nix {
        inherit lib pkgs startupSections;
        developmentSections = [ workspaceGuide ];
      }).hosts;
      hosts = guideHosts [ docLockGuide ] ../modules/home/workspace-backend/guide-worktrunk.md;
      dojjoHosts = guideHosts [ docLockGuide ] ../modules/home/workspace-backend/guide-dojjo.md;
      unlockedHosts = guideHosts [ ] ../modules/home/workspace-backend/guide-worktrunk.md;
      # Each backend's guide names only its own isolation commands.
      workspaceGuideFits = backendHosts: required: forbidden:
        lib.all
          (host:
            lib.all (text: lib.hasInfix text host.development.content) required
            && lib.all (text: !(lib.hasInfix text host.development.content)) forbidden)
          (lib.attrValues backendHosts);
      hasWord = word: text:
        lib.any
          (line:
            builtins.match ".*(^|[^A-Za-z0-9_])${word}($|[^A-Za-z0-9_]).*" line != null)
          (lib.splitString "\n" text);
      contentForHost = host:
        lib.concatStringsSep "\n" (map (guide: guide.content) ([
          host.startup
          host.development
        ] ++ lib.attrValues host.languages));
      count = marker: text: builtins.length (lib.splitString marker text) - 1;
      requiredSections = [
        "## Working contract"
        "## Completion"
        "## What I need from you"
        "## Command routing"
        "## Code search"
        "## Python"
        "## Go"
        "## Version control"
        "## Git hooks"
        "## Parallel checkouts"
        "## Code quality"
        "## Current-state integrity"
        "## Writing"
        "## Docs lock"
      ];
      onceSections = [
        "## Working contract"
        "## Code quality"
        "## Current-state integrity"
        "## Command routing"
        "## Parallel checkouts"
        "## Docs lock"
        "## JavaScript and TypeScript"
        "## Python"
        "## Go"
        "## Rust"
      ];
      # The adapter line that links human-documents.md must name ADRs, or an
      # agent writing one never loads the ADR rules.
      documentsTriggerNamesAdr = host:
        lib.any
          (line: lib.hasInfix "~/${host.humanDocuments.target}" line && lib.hasInfix "ADR" line)
          (lib.splitString "\n" host.startup.content);
      # The adapter line that links development.md must name JJ workspaces, or
      # an agent reaches for a Git worktree before it loads Parallel checkouts.
      workspacesTriggerNamesJj = host:
        lib.any
          (line: lib.hasInfix "~/${host.development.target}" line && lib.hasInfix "JJ workspace" line)
          (lib.splitString "\n" host.startup.content);
      # The adapter line that links the language files must name each language,
      # or an agent writing Go never connects its task to go.md.
      languagesTriggerNamesEach = host:
        lib.any
          (line:
            lib.hasInfix "~/${host.languages.typescript.target}" line
            && lib.all (language: lib.hasInfix "${language}.md" line) (lib.attrNames host.languages)
            && lib.all (name: lib.hasInfix name line) [ "TypeScript" "Python" "Go" "Rust" ])
          (lib.splitString "\n" host.startup.content);
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
            (guide: guide.target != host.startup.target
              && !(builtins.elem guide (lib.attrValues host.languages)))
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
    assert lib.hasInfix "## ADRs and domain documents" hosts.claude.humanDocuments.content;
    assert !(lib.hasInfix "## Plain English" hosts.claude.startup.content);
    assert !(lib.hasInfix "ste80" (contentForHost hosts.claude));
    assert lib.all
      (name:
        count "## Plain English" hosts.${name}.startup.content == 1
        && lib.hasInfix "~/.agents/skills/ste80/SKILL.md" hosts.${name}.startup.content)
      [ "general" "codex" "omp" "antigravity" ];
    assert hosts.antigravity.startup.target == ".gemini/config/AGENTS.md";
    assert hosts.antigravity.startup.content == hosts.general.startup.content;
    assert lib.all documentsTriggerNamesAdr
      (builtins.filter (host: host ? humanDocuments) (lib.attrValues hosts));
    assert lib.all workspacesTriggerNamesJj (lib.attrValues hosts ++ lib.attrValues dojjoHosts);
    assert lib.all languagesTriggerNamesEach (lib.attrValues hosts);
    assert lib.all
      (name: hosts.${name}.startup.content
        == unlockedHosts.${name}.startup.content + "\n" + builtins.readFile docLockGuide)
      (builtins.attrNames hosts);
    pkgs.runCommand "unit-agent-guides" { } ''
      touch $out
    '';
  unit-shell-guard = shellTest "unit-shell-guard" {
    script = ../modules/home/claude/hooks/shell-guard-test.sh;
    inputs = [ pkgs.jq pkgs.gnugrep pkgs.gnused pkgs.gawk pkgs.zoxide ];
    args = [ ../modules/home/claude/hooks/shell-guard.sh ];
  };
  unit-search-guard = shellTest "unit-search-guard" {
    script = ../modules/home/claude/hooks/search-guard-test.sh;
    inputs = [ pkgs.jq pkgs.gnugrep pkgs.gnused pkgs.coreutils ];
    args = [ ../modules/home/claude/hooks/search-guard.sh ];
  };
  unit-doc-lock = shellTest "unit-doc-lock" {
    script = ../modules/home/doc-lock/doc-lock-test.sh;
    inputs = [ pkgs.jq pkgs.git pkgs.coreutils ];
    args = [ (lib.getExe pkgs.martin.doc-lock) ];
  };
  unit-comment-lint = pkgs.runCommand "unit-comment-lint" { nativeBuildInputs = [ pkgs.bash pkgs.jq pkgs.ast-grep pkgs.findutils pkgs.gnugrep pkgs.coreutils ]; } ''
    cp -R ${self} src
    chmod -R u+w src
    cd src
    patchShebangs scripts tests/unit modules/home/doc-lock
    bash ./tests/unit/comment-lint-test.sh ./scripts/comment-lint.sh
    bash ./scripts/comment-lint.sh
    touch $out
  '';
  unit-jj-pr = shellTest "unit-jj-pr" {
    script = ../modules/home/jj-pr/jj-pr-test.sh;
    inputs = [ pkgs.git pkgs.gnugrep pkgs.jujutsu pkgs.coreutils ];
    args = [ (lib.getExe pkgs.martin.jj-pr) ];
  };
  unit-doc-lock-extension = pkgs.runCommand "unit-doc-lock-extension" { nativeBuildInputs = [ pkgs.bun pkgs.git ]; } ''
    export HOME=$TMPDIR
    bun ${../modules/home/doc-lock/agent-extension-test.ts} ${pkgs.martin.doc-lock-extension}
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
      inherit (omp) economy;
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
    assert omp.normal.modelRoles.default == "google-antigravity/gemini-3.8-flash:high";
    assert lib.all (lib.hasPrefix "openai-codex/") (lib.attrValues (builtins.removeAttrs omp.normal.modelRoles [ "default" ]));
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

  # Load the rendered zshrc in a sandboxed zsh to verify keymap tables across
  # default, null-dirjump, and disabled search scenarios.
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

  # Module-level evals of the agent surface, workspace backend, and zsh
  # toggles. They need no host, so they run apart from the host eval.
  unit-module-seams = callTest ./unit/module-seams-test.nix { };

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

  # Evaluating Linux configs forces agent-skills IFD, so skip on Darwin and run
  # on the x86_64-linux CI builder.
  integration-home-linux-purity = onlyOn "linux" "integration-home-linux-purity"
    (callTest ./integration/home-linux-purity-test.nix {
      x230ConfigurationInput = self.nixosConfigurations.x230;
      vmConfigurationInput = self.nixosConfigurations.vm-aarch64-utm;
    });

  # Darwin-only: exact-value lock-in for the macOS settings host "f" commits to.
  # macOS settings have no meaning on the NixOS hosts, so this is a no-op skip
  # off-darwin (the CI matrix still runs it on its native macOS builder).
  integration-darwin-settings = onlyOn "darwin" "integration-darwin-settings"
    (callTest ./integration/darwin-settings-test.nix {
      darwinConfigurationInput = self.darwinConfigurations."f";
    });


  smoke-build-oh-my-pi = onlyOn "darwin" "smoke-build-oh-my-pi"
    (pkgs.runCommand "smoke-build-oh-my-pi" { } ''
      echo "Building oh-my-pi as a Darwin smoke test..."
      test -x ${pkgs.martin.oh-my-pi}/bin/omp
      touch $out
    '');

  smoke-build-toolchain = pkgs.runCommand "smoke-build-toolchain" { } (
    ''
      echo "Checking required Nix-only dotfiles toolchain commands..."
      ${lib.getExe pkgs.prek} --version
      ${lib.getExe pkgs.oxlint} --version
      ${lib.getExe pkgs.oxfmt} --version
      ${lib.getExe pkgs.tsgolint} --help >/dev/null
      ${lib.getExe pkgs.typescript} --version
      ${lib.getExe pkgs.martin.uv-bin} --version
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
})
