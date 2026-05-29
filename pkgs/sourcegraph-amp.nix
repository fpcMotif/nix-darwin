# Sourcegraph Amp CLI (binary `amp`).
#
# This intentionally does not use nixpkgs#amp: that package is the unrelated
# amp.rs text editor. Sourcegraph publishes Amp as the npm package
# @sourcegraph/amp, with one native keyring dependency.
#
# Bumping (no hash dance — `importNpmLock` derives deps from the lockfile):
#   1. find current version: npm view @sourcegraph/amp version
#   2. update ./sourcegraph-amp/package.json and `version` below.
#   3. regenerate the lock:
#        (cd ~/.config/nix-darwin/pkgs/sourcegraph-amp && npm install --package-lock-only)
#   4. nix build .#martin.sourcegraph-amp

{ lib
, buildNpmPackage
, importNpmLock
, nodejs_24
,
}:

buildNpmPackage {
  pname = "sourcegraph-amp";
  version = "0.0.1778732631-gc5875c-singleexe";

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

        cat > $out/bin/amp <<EOF
    #!/bin/sh
    if [ "\$1" = update ] || [ "\$1" = up ]; then
      printf '%s\n' "amp is installed through Nix on this machine."
      printf '%s\n' "Update ~/.config/nix-darwin/pkgs/sourcegraph-amp/package.json, then run darwin-rebuild switch --flake ~/.config/nix-darwin."
      exit 0
    fi
    export NODE_PATH="$out/libexec/sourcegraph-amp/node_modules"
    exec ${nodejs_24}/bin/node --no-warnings "$out/libexec/sourcegraph-amp/node_modules/@sourcegraph/amp/dist/main.js" "\$@"
    EOF
        chmod 755 $out/bin/amp

        runHook postInstall
  '';

  meta = {
    description = "CLI for Amp, the Sourcegraph agentic coding tool";
    homepage = "https://ampcode.com/";
    license = lib.licenses.unfree;
    mainProgram = "amp";
    platforms = [ "aarch64-darwin" ];
  };
}
