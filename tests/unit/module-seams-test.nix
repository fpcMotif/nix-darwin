{ pkgs
, lib
, inputs
, ...
}:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };

  hasPackage = name: packages:
    lib.any (pkg: lib.getName pkg == name) packages;

  # The workspace-backend module alone, for platforms this host cannot evaluate
  # in full. Returns the failed assertion messages.
  backendAssertionFailures = system: backend:
    let
      evaluated = import ../lib/agent-surface-eval.nix { inherit lib; } {
        pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [ (import ../../pkgs) ];
        };
        modules = [
          ../../modules/home/workspace-backend
          { martin.development.workspaceBackend = backend; }
        ];
      };
    in
    map (a: a.message) (builtins.filter (a: !a.assertion) evaluated.assertions);

  docLockSurface = docLock: (import ../lib/agent-surface-eval.nix { inherit lib; } {
    inherit pkgs;
    modules = [ ../../modules/home/doc-lock { martin.development.docLock = docLock; } ];
  }).martin.agentSurface;
  lockedSurface = docLockSurface true;
  unlockedSurface = docLockSurface false;

  agentSurfaceChecks = [
    (helpers.assertTest "doc-lock-surface-toggles-every-adapter"
      (lockedSurface.claudeHooks.add != [ ] && lockedSurface.claudeHooks.remove == [ ]
        && unlockedSurface.claudeHooks.add == [ ]
        && unlockedSurface.claudeHooks.remove == lockedSurface.claudeHooks.add
        && lib.hasInfix "doc-lock grant" lockedSurface.codexRequirements
        && unlockedSurface.codexRequirements == ""
        && lockedSurface.guideSections.startup == [ ../../modules/home/doc-lock/guide.md ]
        && unlockedSurface.guideSections.startup == [ ])
      "docLock should add Claude hooks, Codex requirements, and the guide section when on, and remove the Claude hooks when off")

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

  # Evaluate modules/home/shell/zsh.nix standalone so toggle variants do not
  # pay for a full host evaluation.
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
in
helpers.testSuite "module-seams"
  (agentSurfaceChecks ++ viModeToggleChecks ++ searchToggleChecks ++ modularShellChecks)
