{ lib
, stdenvNoCC
, fetchurl
, undmg
,
}:

# Upstream-prebuilt Zed Preview. Matches the same DMG-unpack pattern used
# by raycast/dropbox/google-drive in this repo: bump `version` and `hash`
# (or let the nightly auto-update workflow do it). Skips the multi-hour
# Rust compile that the upstream flake otherwise triggers when the rev
# isn't already in zed.cachix.org.

stdenvNoCC.mkDerivation rec {
  pname = "zed-editor-preview";
  version = "1.3.3-pre";

  src = fetchurl {
    url = "https://github.com/zed-industries/zed/releases/download/v${version}/Zed-aarch64.dmg";
    name = "Zed-aarch64.dmg";
    hash = "sha256-hmpSYYv9tD2t73DEVZFYwc/KJCLdeNVXfHtFKaOU6Rg=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];

  # The DMG bundles a single .app whose name varies per channel
  # (`Zed Preview.app` for preview builds). Detect rather than hardcode so
  # bumping to a stable / nightly DMG keeps working.
  installPhase = ''
    runHook preInstall

    app="$(find . -maxdepth 1 -name '*.app' -print -quit)"
    if [ -z "$app" ]; then
      echo "zed-preview: no .app bundle found in DMG" >&2
      ls -la
      exit 1
    fi

    mkdir -p "$out/Applications" "$out/bin"
    cp -R "$app" "$out/Applications/"
    appName="$(basename "$app")"

    # `cli` is the helper binary that locates the surrounding .app bundle
    # by walking up its argv[0]. Home Manager's `programs.zed-editor`
    # wraps `$out/bin/zeditor`; nixpkgs also exposes that name for the
    # Darwin build.
    ln -s "$out/Applications/$appName/Contents/MacOS/cli" "$out/bin/zeditor"
    ln -s "$out/Applications/$appName/Contents/MacOS/cli" "$out/bin/zed"

    runHook postInstall
  '';

  meta = {
    description = "Zed Preview (prebuilt universal DMG from upstream)";
    homepage = "https://zed.dev/releases/preview";
    changelog = "https://github.com/zed-industries/zed/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "zeditor";
    platforms = [ "aarch64-darwin" ];
  };
}
