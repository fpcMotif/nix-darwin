{ inputs, system, self }:

let
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = (import ../lib/overlays.nix { inherit inputs; }).all;
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
  unit-git-merge-pkgnix = shellTest "unit-git-merge-pkgnix" {
    script = ./unit/git-merge-pkgnix-test.sh;
    inputs = [ pkgs.git pkgs.jq pkgs.gnugrep pkgs.gnused pkgs.diffutils pkgs.coreutils ];
    args = [ ../scripts ];
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
  unit-agent-guides = callTest ./unit/agent-guides-test.nix { };
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
  unit-agy-guard = shellTest "unit-agy-guard" {
    script = ../modules/home/antigravity/agy-guard-test.sh;
    inputs = [ pkgs.jq pkgs.gnugrep pkgs.gnused pkgs.gawk pkgs.zoxide pkgs.coreutils ];
    args = [ ../modules/home/antigravity/agy-guard.sh ../modules/home/claude/hooks/shell-guard.sh ];
  };
  unit-browser-file-guard = shellTest "unit-browser-file-guard" {
    script = ../modules/home/claude/hooks/browser-file-guard-test.sh;
    inputs = [ pkgs.jq pkgs.gnugrep ];
    args = [ ../modules/home/claude/hooks/browser-file-guard.sh ];
  };
  unit-context-handoff = shellTest "unit-context-handoff" {
    script = ../modules/home/claude/hooks/context-handoff-test.sh;
    inputs = [ pkgs.jq pkgs.coreutils ];
    args = [ ../modules/home/claude/hooks/context-handoff.sh ];
  };
  unit-shell-routing = shellTest "unit-shell-routing" {
    script = ../modules/home/claude/hooks/shell-routing-test.sh;
    inputs = [ pkgs.jq pkgs.gnugrep ];
    args = [ ../modules/home/claude/hooks/shell-routing.sh ../modules/home/claude/claude-adapter.md ];
  };
  unit-recall = shellTest "unit-recall" {
    script = ../modules/home/recall/recall-test.sh;
    inputs = [ pkgs.jq pkgs.coreutils ];
    args = [ (lib.getExe pkgs.martin.recall) ];
  };
  unit-agent-checkout = shellTest "unit-agent-checkout" {
    script = ../modules/home/workspace-backend/agent-checkout-test.sh;
    inputs = [ pkgs.jq pkgs.git pkgs.jujutsu pkgs.coreutils pkgs.gawk pkgs.gnugrep ];
    args = [ (lib.getExe pkgs.martin.agent-checkout) ];
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
  unit-cleanup-legacy-dotfiles = onlyOn "darwin" "unit-cleanup-legacy-dotfiles"
    (shellTest "unit-cleanup-legacy-dotfiles" {
      script = ./unit/cleanup-legacy-dotfiles-test.sh;
      inputs = [ pkgs.coreutils pkgs.jq ];
      args = [
        (pkgs.writeText "cleanup-legacy-dotfiles.sh"
          self.darwinConfigurations."f".config.home-manager.users.martinfan.home.activation.cleanupLegacyDotfiles.data)
        "${pkgs.coreutils}/bin/true"
      ];
    });

  # Drives wt and djo through create, switch, list, remove, hooks, and a
  # backend switch in disposable repositories. It uses the config files and Zsh
  # lines host "f" ships under each backend, so it runs where "f" builds.
  unit-workspace-backend-lifecycle = onlyOn "darwin" "unit-workspace-backend-lifecycle" (
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
  );
  unit-skill-router = callTest ./unit/skill-router-test.nix { };
  unit-skill-hygiene = callTest ./unit/skill-hygiene-test.nix { };
  unit-pstack-hygiene = callTest ./unit/pstack-hygiene-test.nix { };
  unit-ai-model-routing = callTest ./unit/ai-model-routing-test.nix { };

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

  smoke-build-agent-trace = pkgs.runCommand "smoke-build-agent-trace" { } ''
    echo "Building tools/agent-trace/go..."
    test -x ${lib.getExe pkgs.martin.agent-trace}
    touch $out
  '';

  smoke-build-iets = onlyOn "darwin" "smoke-build-iets"
    (pkgs.runCommand "smoke-build-iets" { } ''
      echo "Building iets with pkgs/iets/host-system.patch applied..."
      test -x ${pkgs.martin.iets-classic}/bin/nix
      touch $out
    '');

  smoke-build-toolchain = pkgs.runCommand "smoke-build-toolchain" { } (
    ''
      echo "Checking required Nix-only dotfiles toolchain commands..."
      ${lib.getExe pkgs.zig} version
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
