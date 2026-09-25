# dojjo (binary `djo`) — workspace manager for jj, modelled on Worktrunk
# (tjarvstrand/dojjo). It shells out to `jj` for every operation, so jj stays
# the version-control system; dojjo adds sibling paths, `cd` integration, and
# lifecycle hooks. Selected by martin.development.workspaceBackend = "dojjo".
#
# Why a prebuilt release: upstream is a Dart AOT executable. Building it from
# source would need a Dart toolchain and a pub lockfile translation for one
# experimental CLI. The release asset links only macOS system frameworks.
#
# Stripping would cut the AOT snapshot appended to the Mach-O, so the bytes
# stay as downloaded. The hash matches the digest GitHub publishes for the
# asset. The install check runs the binary, so a broken download fails here.
#
# Bumping: deliberate only. There is no updater, because the experiment must
# stay reproducible; re-prefetch the versioned URL and re-audit the README's
# config and hook claims against the new source.

{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.2.2";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/tjarvstrand/dojjo/releases/download/v${version}/djo-macos-arm64";
      hash = "sha256-zNMpIwtiJn5Y+P21mPyhIx5lwNlhDZugH+O/v4dwFZg=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "dojjo-bin: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "dojjo-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm0755 "$src" "$out/bin/djo"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    [ "$("$out/bin/djo" --version)" = "${version}" ]
    runHook postInstallCheck
  '';

  meta = {
    description = "dojjo — Worktrunk-style workspace manager for jj, prebuilt release";
    homepage = "https://github.com/tjarvstrand/dojjo";
    changelog = "https://github.com/tjarvstrand/dojjo/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "djo";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
