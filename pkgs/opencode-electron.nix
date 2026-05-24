# opencode Electron desktop app (sst/opencode `opencode-electron-*`).
#
# The Electron variant ships as a signed `.app` inside a zip on darwin and as
# an .AppImage on linux. We unpack the .app bundle into $out/Applications and
# expose the inner binary as $out/bin/opencode-electron for symmetry with the
# CLI build.
#
# Bumping: tracked together with pkgs/opencode.nix via scripts/update-opencode.sh.

{ lib
, stdenvNoCC
, fetchurl
, unzip
, makeBinaryWrapper
,
}:

let
  version = "1.15.5";

  # Upstream renamed `opencode-electron-*` → `opencode-desktop-*` in v1.15.x.
  # The .app bundle and binary inside it stayed the same; we keep the
  # nix-side derivation name `opencode-electron` for stability.
  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-desktop-mac-arm64.zip";
      hash = "sha256-0iLLKMYKUEjj2aVqY1opASTAP2RFtPxfdwIEKUUsmWQ=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "opencode-electron: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "opencode-electron";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  dontUnpack = true;

  nativeBuildInputs = [ unzip makeBinaryWrapper ];

  installPhase = ''
    runHook preInstall

    appsdir="$out/Applications"
    mkdir -p "$appsdir" "$out/bin"

    # Zip ships an opencode.app bundle at the root.
    unzip -q "$src" -d "$appsdir"

    bundle="$(find "$appsdir" -maxdepth 2 -name '*.app' -type d | head -1)"
    test -n "$bundle" || (echo "no .app bundle in zip" >&2; ls -la "$appsdir"; exit 1)

    inner="$bundle/Contents/MacOS"
    binname="$(ls "$inner" | head -1)"
    test -n "$binname" || (echo "no binary inside $inner" >&2; exit 1)

    # Stable launcher: `opencode-electron` reaches the .app's MacOS binary.
    makeBinaryWrapper "$inner/$binname" "$out/bin/opencode-electron"

    runHook postInstall
  '';

  meta = {
    description = "opencode Electron desktop app (sst/opencode)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode-electron";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
