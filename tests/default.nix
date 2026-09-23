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
  unit-auto-update = pkgs.runCommand "unit-auto-update" { nativeBuildInputs = [ pkgs.bash pkgs.gnugrep ]; } ''
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
  unit-claude-md =
    let
      renderAgentGuide = import ../modules/home/agent-instructions/render-agent-guide.nix { inherit lib; };
      renderedClaudeGuide = pkgs.writeText "rendered-claude-guide.md" (renderAgentGuide [
        ../modules/home/claude/CLAUDE.md
        ../modules/home/agent-instructions/shared/working-contract.md
        ../modules/home/agent-instructions/shared/quality-and-style.md
      ]);
      renderedClaudeDevelopment = pkgs.writeText "rendered-claude-development.md" (renderAgentGuide [
        ../modules/home/claude/development.md
        ../modules/home/agent-instructions/shared/development.md
      ]);
    in
    pkgs.runCommand "unit-claude-md" { nativeBuildInputs = [ pkgs.bash pkgs.gnugrep ]; } ''
      bash ${./unit/claude-md-test.sh} \
        ${renderedClaudeGuide} \
        ${../modules/home/claude.nix} \
        ${../modules/home/claude/human-documents.md} \
        ${renderedClaudeDevelopment}
      touch $out
    '';
  unit-agent-guides =
    let
      renderAgentGuide = import ../modules/home/agent-instructions/render-agent-guide.nix { inherit lib; };
      sharedContract = ../modules/home/agent-instructions/shared/working-contract.md;
      sharedDevelopment = ../modules/home/agent-instructions/shared/development.md;
      sharedQuality = ../modules/home/agent-instructions/shared/quality-and-style.md;
      guides = {
        general = renderAgentGuide [
          ../modules/home/agent-instructions/AGENTS.md
          sharedContract
          sharedQuality
        ];
        codex = renderAgentGuide [
          ../modules/home/agent-instructions/codex/AGENTS.md
          sharedContract
          sharedQuality
        ];
        codexDevelopment = renderAgentGuide [
          ../modules/home/agent-instructions/codex/guidance/development.md
          sharedDevelopment
        ];
        omp = renderAgentGuide [
          ../modules/home/agent-instructions/omp/agent/AGENTS.md
          sharedContract
          sharedQuality
        ];
        ompDevelopment = renderAgentGuide [
          ../modules/home/agent-instructions/omp/agent/guidance/development.md
          sharedDevelopment
        ];
        claude = renderAgentGuide [
          ../modules/home/claude/CLAUDE.md
          sharedContract
          sharedQuality
        ];
        claudeDevelopment = renderAgentGuide [
          ../modules/home/claude/development.md
          sharedDevelopment
        ];
      };
      count = marker: text: builtins.length (lib.splitString marker text) - 1;
      once = marker: text: count marker text == 1;
      commonGuides = with guides; [ general codex omp claude ];
      developmentGuides = with guides; [
        (builtins.readFile sharedDevelopment)
        codexDevelopment
        ompDevelopment
        claudeDevelopment
      ];
      noModelCache = text: lib.all (term: !(lib.hasInfix term text)) [
        "gpt-"
        "Gemini"
        "Astra"
        "Sol"
        "Terra"
        "Luna"
      ];
    in
    assert lib.all (once "## Working contract") commonGuides;
    assert lib.all (once "## Code quality") commonGuides;
    assert lib.all (once "## Command routing") developmentGuides;
    assert lib.all noModelCache commonGuides;
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
    assert lib.all (lib.hasPrefix "openai-codex/gpt-6-") omp.normal.enabledModels;
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
      run = scenario: initFile: fzfGitArg: ''
        SCENARIO=${scenario} bash ${./unit/zsh-vi-mode-test.sh} ${initFile} \
          ${pkgs.zsh-vi-mode} ${pkgs.fzf} \
          ${pkgs.zsh-autosuggestions} ${pkgs.zsh-syntax-highlighting} \
          ${fzfGitArg}
      '';
    in
    pkgs.runCommand "unit-zsh-vi-mode"
      {
        nativeBuildInputs = [ pkgs.bash pkgs.zsh pkgs.gnugrep ];
      }
      ''
        ${run "default" (mkInit "default" { }) "${pkgs.fzf-git-sh}"}
        ${run "null-dirjump" (mkInit "null-dirjump" { dirJumpNull = true; }) "${pkgs.fzf-git-sh}"}
        ${run "off" (mkInit "off" { searchEnable = false; }) ""}
        touch $out
      '';

  # Integration tests
  integration-configurations-eval =
    if pkgs.stdenv.hostPlatform.isDarwin then
      callTest ./integration/configurations-eval-test.nix
        {
          evalScope = "darwin";
          darwinConfigurationInput = self.darwinConfigurations."f";
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
