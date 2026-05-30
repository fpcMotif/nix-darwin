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
  unit-mksystem = callTest ./unit/mksystem-test.nix {};
  unit-overlay = callTest ./unit/overlay-test.nix {};
  unit-format = callTest ./unit/format-test.nix {};

  # Integration tests
  integration-configurations-eval =
    if pkgs.stdenv.isDarwin then
      callTest ./integration/configurations-eval-test.nix {
        evalScope = "darwin";
        darwinConfig = self.darwinConfigurations."f".config;
      }
    else
      callTest ./integration/configurations-eval-test.nix {
        evalScope = "nixos";
        wslConfig = self.nixosConfigurations.wsl.config;
        x230Config = self.nixosConfigurations.x230.config;
        vmConfig = self.nixosConfigurations.vm-aarch64-utm.config;
      };

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
}
