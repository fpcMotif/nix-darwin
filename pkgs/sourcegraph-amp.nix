# Sourcegraph Amp CLI (binary `amp`).
#
# This intentionally does not use nixpkgs#amp: that package is the unrelated
# amp.rs text editor. Sourcegraph publishes Amp as the npm package
# @sourcegraph/amp, which currently wraps a native @ampcode/cli binary.
#
# Bumping (no hash dance — `importNpmLock` derives deps from the lockfile):
#   1. find current version: npm view @sourcegraph/amp version
#   2. update ./sourcegraph-amp/package.json and `version` below.
#   3. regenerate the lock:
#        (cd ~/.config/nix-darwin/pkgs/sourcegraph-amp && npm install --package-lock-only)
#   4. nix build .#martin.sourcegraph-amp

{ lib
, stdenv
, buildNpmPackage
, importNpmLock
, nodejs-slim_26
,
}:

let
  platformCliPackage = {
    aarch64-darwin = "@ampcode/cli-darwin-arm64";
    x86_64-darwin = "@ampcode/cli-darwin-x64";
    aarch64-linux = "@ampcode/cli-linux-arm64";
    x86_64-linux = "@ampcode/cli-linux-x64";
  }.${stdenv.hostPlatform.system} or (throw "sourcegraph-amp: unsupported platform ${stdenv.hostPlatform.system}; upstream @sourcegraph/amp ships native CLI packages for Darwin and glibc Linux on aarch64/x86_64");

  platformCliPath = "node_modules/${platformCliPackage}/amp";
in
buildNpmPackage {
  pname = "sourcegraph-amp";
  version = "0.0.1783832508-gf7599b";

  src = ./sourcegraph-amp;

  npmDeps = importNpmLock {
    npmRoot = ./sourcegraph-amp;
  };

  npmConfigHook = importNpmLock.npmConfigHook;

  dontNpmBuild = true;

  installPhase = ''
        runHook preInstall

        mkdir -p $out/libexec/sourcegraph-amp $out/bin
        cp -R node_modules $out/libexec/sourcegraph-amp/

        amp_cli="$out/libexec/sourcegraph-amp/${platformCliPath}"
        if [ ! -x "$amp_cli" ]; then
          printf '%s\n' "sourcegraph-amp: expected executable not found: $amp_cli" >&2
          printf '%s\n' "The @sourcegraph/amp npm package layout may have changed; check pkgs/sourcegraph-amp/package-lock.json." >&2
          exit 1
        fi

        cat > $out/bin/amp <<EOF
    #!/bin/sh
    if [ "\$1" = update ] || [ "\$1" = up ]; then
      printf '%s\n' "amp is installed through Nix on this machine."
      printf '%s\n' "Update ~/.config/nix-darwin/pkgs/sourcegraph-amp/package.json, then run darwin-rebuild switch --flake ~/.config/nix-darwin."
      exit 0
    fi
    export PATH="${lib.makeBinPath [ nodejs-slim_26 ]}:\$PATH"
    exec "$amp_cli" "\$@"
    EOF
        chmod 755 $out/bin/amp

        runHook postInstall
  '';

  meta = {
    description = "CLI for Amp, the Sourcegraph agentic coding tool";
    homepage = "https://ampcode.com/";
    license = lib.licenses.unfree;
    mainProgram = "amp";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
