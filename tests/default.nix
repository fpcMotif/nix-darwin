# Test entry point for the flake.
#
# Returns `{ checks, groups }`:
#   * `checks` — one derivation per test. Each either builds successfully
#     (test passes) or fails to build (test fails, with an explanation).
#     Wired into the flake's `checks.<system>` output so `nix flake check`
#     can run them.
#   * `groups` — named subsets of `checks`' attribute names (plain string
#     lists, not derivations). Wired into the flake's `checkGroups.<system>`
#     output. This is the SINGLE SOURCE for "what does CI / justfile / the
#     nightly guard actually build" — consumers enumerate a group (e.g.
#     `nix eval --json .#checkGroups.<system>.<group>`, see
#     `scripts/lib/check-group.sh`) instead of hardcoding attr-name lists.
#     Adding a check to a group here is enough; no YAML/justfile edit needed.
{ inputs, system, self }:

let
  pkgs = import inputs.nixpkgs {
    inherit system;
    overlays = [ (import ../pkgs) ];
    config.allowUnfree = true;
  };
  lib = pkgs.lib;

  callTest = path: extraArgs: import path ({ inherit inputs system pkgs lib self; } // extraArgs);

  checks = {
    smoke = pkgs.runCommand "smoke-test" { } ''
      echo "PASS test infrastructure OK on ${system}"
      touch $out
    '';

    # Unit tests
    unit-mksystem = callTest ./unit/mksystem-test.nix { };
    unit-overlay = callTest ./unit/overlay-test.nix { };
    unit-format = callTest ./unit/format-test.nix { };
    unit-skill-router = callTest ./unit/skill-router-test.nix { };

    # Integration tests
    integration-configurations-eval =
      if pkgs.stdenv.isDarwin then
        callTest ./integration/configurations-eval-test.nix
          {
            evalScope = "darwin";
            darwinConfigurationInput = self.darwinConfigurations."f";
          }
      else
        callTest ./integration/configurations-eval-test.nix {
          evalScope = "nixos";
          wslConfigurationInput = self.nixosConfigurations.wsl;
          x230ConfigurationInput = self.nixosConfigurations.x230;
          vmConfigurationInput = self.nixosConfigurations.vm-aarch64-utm;
        };

    # Linux-only: the shared Home Manager profile must not leak macOS paths or
    # tools into the Linux hosts. Evaluating the Linux configs requires a Linux
    # builder (agent-skills resolves its bundle via import-from-derivation), so
    # this is a no-op skip on Darwin; CI runs it on the x86_64-linux builder.
    integration-home-linux-purity =
      if pkgs.stdenv.isDarwin then
        pkgs.runCommand "integration-home-linux-purity-skipped" { } ''
          echo "Skipping Linux-only home purity test on ${system}"
          touch $out
        ''
      else
        callTest ./integration/home-linux-purity-test.nix {
          wslConfigurationInput = self.nixosConfigurations.wsl;
          x230ConfigurationInput = self.nixosConfigurations.x230;
          vmConfigurationInput = self.nixosConfigurations.vm-aarch64-utm;
        };

    # Darwin-only: exact-value lock-in for the macOS settings host "f" commits to.
    # macOS settings have no meaning on the NixOS hosts, so this is a no-op skip
    # off-darwin (the CI matrix still runs it on its native macOS builder).
    integration-darwin-settings =
      if pkgs.stdenv.isDarwin then
        callTest ./integration/darwin-settings-test.nix
          {
            darwinConfigurationInput = self.darwinConfigurations."f";
          }
      else
        pkgs.runCommand "integration-darwin-settings-skipped" { } ''
          echo "Skipping darwin-only macOS settings test on ${system}"
          touch $out
        '';


    # Smoke builds: verify these derivations actually build correctly.
    smoke-build-common = pkgs.runCommand "smoke-build-common" { } ''
      echo "Building mgrep as a common package smoke test..."
      ${pkgs.mgrep}/bin/mgrep --version
      touch $out
    '';

    smoke-build-oh-my-pi = pkgs.runCommand "smoke-build-oh-my-pi" { } (
      if pkgs.stdenv.isDarwin then ''
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
        ${lib.getExe pkgs.typescript-go} --version
        ${lib.getExe pkgs.uv} --version
        ${lib.getExe pkgs.ruff} --version
      ''
      # bun is shipped as the canary prebuilt (aarch64-darwin only), so validate
      # the binary that is actually installed rather than stock nixpkgs `bun`.
      + lib.optionalString pkgs.stdenv.isDarwin ''
        ${lib.getExe pkgs.martin.bun-canary-bin} --version
        test -L ${pkgs.martin.bun-canary-bin}/bin/bunx
      ''
      + ''
        touch $out
      ''
    );
  };
in
{
  inherit checks;

  # Named subsets of `builtins.attrNames checks`, enumerated (not
  # hardcoded) by every consumer. Nothing enforces these stay subsets of
  # `checks` at eval time — the equivalence-diff verification step in the
  # PR that introduced this is the guardrail; keep it in sync by hand.
  groups = {
    # Everything `.github/workflows/build.yml` builds on both check systems
    # (the `flake-check` x86_64-linux job and the `darwin` macos-14 job run
    # this same logical list). Deliberately excludes `unit-skill-router` —
    # that matches today's build.yml as-is; this refactor centralizes the
    # list, it does not silently widen it.
    ci-gate = [
      "smoke"
      "unit-mksystem"
      "unit-overlay"
      "unit-format"
      "integration-configurations-eval"
      "integration-home-linux-purity"
      "integration-darwin-settings"
      "smoke-build-common"
      "smoke-build-oh-my-pi"
      "smoke-build-toolchain"
    ];

    # `justfile`'s `check` recipe. `darwinConfigurations.f.system` is built
    # alongside this group but stays hardcoded in the justfile — it's a
    # flake output, not a member of `checks.<system>`.
    quick = [
      "unit-overlay"
      "unit-skill-router"
      "integration-configurations-eval"
    ];

    # `.github/workflows/auto-update.yml`'s nightly guard. MUST stay this
    # exact small, IFD-safe subset: `nix flake check --no-build` cannot
    # evaluate the agent-skills import-from-derivation bundle path (see
    # modules/home/claude.nix), so the nightly guard can only afford checks
    # that are both cheap AND IFD-safe to build on a plain Linux runner.
    # Don't grow this group without re-verifying both constraints.
    nightly-guard = [
      "unit-overlay"
      "integration-configurations-eval"
    ];
  };
}
