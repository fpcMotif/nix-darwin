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

  callTest = path: import path {
    inherit inputs system pkgs lib self;
  };
in
{
  smoke = pkgs.runCommand "smoke-test" { } ''
    echo "PASS test infrastructure OK on ${system}"
    touch $out
  '';

  # Unit tests
  unit-mksystem = callTest ./unit/mksystem-test.nix;
  unit-overlay = callTest ./unit/overlay-test.nix;
  unit-format = callTest ./unit/format-test.nix;

  # Integration tests
  integration-configurations-eval = callTest ./integration/configurations-eval-test.nix;

  # Smoke builds: verify these derivations actually build correctly.
  smoke-build-common = pkgs.runCommand "smoke-build-common" { } ''
    echo "Building mgrep as a common package smoke test..."
    ${pkgs.mgrep}/bin/mgrep --version
    touch $out
  '';

  smoke-build-gemini = pkgs.runCommand "smoke-build-gemini" { } (
    if pkgs.stdenv.isDarwin then ''
      echo "Building gemini-cli-preview as a Darwin smoke test..."
      ls -la ${pkgs.martin.gemini-cli-preview}
      touch $out
    '' else ''
      echo "Skipping Darwin-only smoke test on this platform"
      touch $out
    ''
  );

  smoke-build-toolchain = pkgs.runCommand "smoke-build-toolchain" { } ''
    echo "Checking required Nix-only dotfiles toolchain commands..."
    ${lib.getExe pkgs.bun} --version
    test -x ${pkgs.bun}/bin/bunx
    ${lib.getExe pkgs.prek} --version
    ${lib.getExe pkgs.oxlint} --version
    ${lib.getExe pkgs.oxfmt} --version
    ${lib.getExe pkgs.tsgolint} --help >/dev/null
    ${lib.getExe pkgs.typescript-go} --version
    ${lib.getExe pkgs.uv} --version
    ${lib.getExe pkgs.ruff} --version
    touch $out
  '';

  # mkAppFromDmg helper: assert each caller lands a .app under
  # $out/Applications. Catches "helper assembled but $out is empty" —
  # the failure mode `nix flake check` alone wouldn't see.
  smoke-build-dropbox = pkgs.runCommand "smoke-build-dropbox" { } (
    if pkgs.stdenv.isDarwin then ''
      echo "Building dropbox as a Darwin smoke test..."
      test -d ${pkgs.martin.dropbox}/Applications/Dropbox.app
      touch $out
    '' else ''
      echo "Skipping Darwin-only smoke test on this platform"
      touch $out
    ''
  );

  smoke-build-raycast = pkgs.runCommand "smoke-build-raycast" { } (
    if pkgs.stdenv.isDarwin then ''
      echo "Building raycast as a Darwin smoke test..."
      test -d ${pkgs.martin.raycast}/Applications/Raycast.app
      touch $out
    '' else ''
      echo "Skipping Darwin-only smoke test on this platform"
      touch $out
    ''
  );
}
