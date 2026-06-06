# Unit tests for the custom package overlay in pkgs/default.nix.
#
# Verifies the overlay applies cleanly and exposes the expected `martin.*`
# package attributes. We only check that the attributes exist and evaluate
# (drvPath); we do not build them, so the test stays fast and runs on any
# platform.
{ inputs, system, pkgs, lib, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };

  overlay = import ../../pkgs;

  overlaid = import inputs.nixpkgs {
    inherit system;
    overlays = [ overlay ];
    config.allowUnfree = true;
  };

  expected = [
    "bun-canary-bin"
    "google-drive"
    "hammerspoon"
    "raycast"
    "oh-my-pi"
    "pi-coding-agent"
    "sourcegraph-amp"
  ];

  expectedMainPrograms = {
    bun-canary-bin = "bun";
    oh-my-pi = "omp";
    pi-coding-agent = "pi";
    sourcegraph-amp = "amp";
  };

  hasAttr = a: builtins.hasAttr a (overlaid.martin or { });

  isDarwin = lib.hasSuffix "darwin" system;

  # Packages that only build on Darwin (binary cask / macOS-only). On Linux
  # we settle for "attribute exists" instead of evaluating the derivation.
  darwinOnly = [
    "bun-canary-bin"
    "google-drive"
    "hammerspoon"
    "oh-my-pi"
    "pi-coding-agent"
    "raycast"
    "sourcegraph-amp"
  ];
in
helpers.testSuite "overlay" (
  [
    (helpers.assertTest "overlay-is-function"
      (builtins.isFunction overlay)
      "pkgs/default.nix should be a Nixpkgs overlay (a function final: prev: ...)")

    (helpers.assertTest "overlay-exposes-martin-namespace"
      (builtins.isAttrs (overlaid.martin or null))
      "overlay should add a `martin` attribute set to pkgs")
  ]
  ++ (map
    (name:
      helpers.assertTest "overlay-has-${name}"
        (hasAttr name)
        "pkgs.martin.${name} should be exposed by the overlay")
    expected)
  ++ (map
    (name:
      helpers.assertTest "overlay-${name}-evaluates"
        (
          let
            r = builtins.tryEval (overlaid.martin.${name}.drvPath or null);
            skipOnLinux = !isDarwin && builtins.elem name darwinOnly;
          in
          skipOnLinux || (r.success && r.value != null)
        )
        "pkgs.martin.${name} should evaluate to a derivation on this platform")
    expected)
  ++ (map
    (name:
      helpers.assertTest "overlay-${name}-has-description"
        (
          let r = builtins.tryEval (overlaid.martin.${name}.meta.description or "");
          in r.success && r.value != ""
        )
        "pkgs.martin.${name} should expose a meta.description")
    expected)
  ++ (lib.mapAttrsToList
    (name: mainProgram:
      helpers.assertTest "overlay-${name}-main-program"
        (
          let r = builtins.tryEval (overlaid.martin.${name}.meta.mainProgram or null);
          in r.success && r.value == mainProgram
        )
        "pkgs.martin.${name} should expose meta.mainProgram = ${mainProgram}")
    expectedMainPrograms)
)
