{ pkgs, lib, ... }:

let
  # Match modules/home/skill-router.nix: the shipped Bun is the prebuilt canary
  # on Darwin (aarch64-darwin only), stock nixpkgs `bun` everywhere else.
  bun = if pkgs.stdenv.hostPlatform.isDarwin then pkgs.martin.bun-canary-bin else pkgs.bun;

  # Strip node_modules even in dirty working trees so the check never depends
  # on installed packages outside the Nix sandbox.
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
