# Unit test: the skill-router tool's spawn-seam regression suite.
#
# tools/skill-router guards a Command seam (src/command-runner.ts) and a
# skill-read seam (src/file-reader.ts) under RouterRuntime so the
# `discover`/`load` hot path never reaches a real `bunx @tanstack/intent`
# subprocess unless package scope is explicitly requested (ADR-0006), and tests
# do not mutate process HOME to load config fixtures. test/subprocess-gating.test.ts
# pins that contract. The suite is fully hermetic: it injects a RouterRuntime
# with a CommandRunner + ReadText (test/support/doubles.ts), stages only $TMPDIR
# fixtures, and bunfig.toml preloads a guard (test/support/preload.ts) that sets
# SKILL_ROUTER_NO_REAL_SPAWN so any real subprocess — including a network `bunx`
# — throws instead of escaping. That makes it safe to run inside the offline Nix
# sandbox.
#
# This derivation is the ONLY automated gate on the spawn seam: `nix flake check`
# now runs it on every check system, so the protection that previously ran only
# by hand (`bun test` in tools/skill-router) regresses loudly in CI.
{ pkgs, lib, ... }:

let
  # Match modules/home/skill-router.nix: the shipped Bun is the prebuilt canary
  # on Darwin (aarch64-darwin only), stock nixpkgs `bun` everywhere else.
  bun = if pkgs.stdenv.isDarwin then pkgs.martin.bun-canary-bin else pkgs.bun;

  # The flake source already excludes node_modules (.gitignore); drop it again
  # so the check can never depend on a populated node_modules. The suite imports
  # only `bun:test`, `node:*`, and relative `src`, so none is needed and `bun
  # test` installs nothing.
  src = lib.cleanSourceWith {
    name = "skill-router-src";
    src = ../../tools/skill-router;
    filter = path: _type: baseNameOf path != "node_modules";
  };
in
pkgs.runCommand "unit-skill-router"
{
  nativeBuildInputs = [ bun ];
} ''
  echo "Running skill-router spawn-seam regression suite (offline)..."
  cp -R ${src} skill-router
  chmod -R u+w skill-router
  cd skill-router

  # Nix sets HOME to a non-writable sentinel; Bun wants a writable HOME for its
  # cache, and the suite swaps process.env.HOME to a $TMPDIR fixture anyway.
  export HOME="$TMPDIR"
  export DO_NOT_TRACK=1

  # bunfig.toml preloads test/support/preload.ts (SKILL_ROUTER_NO_REAL_SPAWN=1),
  # so a forgotten CommandRunner injection fails offline here instead of spawning
  # `bunx`. No network, no real subprocess — fully hermetic.
  bun test

  touch $out
''
