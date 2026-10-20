{ lib
, stdenvNoCC
, fetchurl
, gnutar
}:

let
  version = "0.24.0";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/modem-dev/hunk/releases/download/v${version}/hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-+Hbx6G1rqI4SCTfrefY4iXYqKf7ZUSNtbeac4/+WeBk=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "hunk-bin: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "hunk-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [ gnutar ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec"
    tar -xzf "$src" -C "$out/libexec"
    mv "$out/libexec"/hunkdiff-* "$out/libexec/hunk"
    chmod 0755 "$out/libexec/hunk/hunk"
    test -f "$out/libexec/hunk/skills/hunk-review/SKILL.md" \
      || (echo "hunk-bin: skills missing after extract" >&2; ls -R "$out/libexec" >&2; exit 1)
    mkdir -p "$out/bin"
    ln -s ../libexec/hunk/hunk "$out/bin/hunk"

    runHook postInstall
  '';

  meta = {
    description = "Hunk — terminal diff viewer for agentic changesets, prebuilt release";
    homepage = "https://github.com/modem-dev/hunk";
    changelog = "https://github.com/modem-dev/hunk/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
