{ lib
, stdenvNoCC
, fetchurl
, _7zz
}:

let
  version = "1.26.0+nightly.3451.d67bbfda3c010bce64a5a9a1bb7977ef2423fd03";

  sources = {
    "aarch64-darwin" = {
      url = "https://zed-nightly-host.nyc3.digitaloceanspaces.com/${version}/Zed-aarch64.dmg";
      hash = "sha256-2i9nUhq4dssEom/vkdOyC/aVlD29eWrOHqTlAGbjkSI=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  source = sources.${system} or (throw "zed-nightly-bin: unsupported system ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "zed-nightly-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  # undmg 1.1.0 only supports HFS+, whereas Zed ships APFS DMGs.
  nativeBuildInputs = [ _7zz ];
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    workdir="$(mktemp -d)"
    # APFS DMGs need two passes through 7zz: first to crack the .dmg
    # container into a raw image, then to extract the APFS volume.
    7zz x -bb0 -bd -y -o"$workdir" "$src" >/dev/null

    img="$(find "$workdir" -maxdepth 2 \
            \( -name '*.hfs' -o -name '*.apfs' -o -name '*.img' \) -print -quit)"
    if [ -n "$img" ]; then
      7zz x -bb0 -bd -y -o"$workdir/extracted" "$img" >/dev/null
      root="$workdir/extracted"
    else
      # Some 7zz builds inline the volume into the first pass.
      root="$workdir"
    fi

    app="$(find "$root" -maxdepth 4 -name '*.app' -type d -print -quit)"
    test -n "$app" || {
      echo "no .app bundle in dmg" >&2
      find "$root" -maxdepth 4 | head -50 >&2
      exit 1
    }

    mkdir -p "$out/Applications"
    cp -R "$app" "$out/Applications/"

    appname="$(basename "$app")"
    mkdir -p "$out/bin"
    ln -s "../Applications/$appname/Contents/MacOS/cli" "$out/bin/zeditor"

    runHook postInstall
  '';

  meta = {
    description = "Zed editor — prebuilt nightly channel binary";
    homepage = "https://zed.dev/";
    license = lib.licenses.gpl3Plus;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "zeditor";
  };
}
