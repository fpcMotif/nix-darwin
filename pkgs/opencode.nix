# opencode CLI / TUI (binary `opencode`).
#
# sst/opencode ships per-platform Bun-compiled standalone binaries as
# release assets on https://github.com/sst/opencode/releases. We deliberately
# do NOT use buildNpmPackage on `opencode-ai`: that npm bootstrapper just
# downloads the same Bun binary at install time, which doesn't compose with
# Nix's sandboxed builds.
#
# Bumping: scripts/update-opencode.sh polls the GitHub releases API for the
# latest tag and refreshes per-platform hashes via the fake-hash dance.

{ lib
, stdenvNoCC
, fetchzip
, fetchurl
, autoPatchelfHook
, unzip
, gnutar
,
}:

let
  version = "1.17.20";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      hash = "sha256-3EIRS7ejEuDGHHFFb+0A0ebYt2R9J5IzElCQgE3AIYs=";
      isZip = true;
    };
    "x86_64-linux" = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.tar.gz";
      hash = "sha256-txAMCtCYD7ol1ZUSO0IZpv3B+9RW3LZIWSNnQeGZxWQ=";
      isZip = false;
    };
    "aarch64-linux" = {
      url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-arm64.tar.gz";
      hash = "sha256-CkFXLoOolusAhoNYnf4J4XuUHQYSJghRDz5fFthtmvw=";
      isZip = false;
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "opencode: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  dontUnpack = true;

  nativeBuildInputs = [
    (if source.isZip then unzip else gnutar)
  ] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    cd "$out/bin"
    ${if source.isZip then "unzip -j" else "tar -xzf"} "$src"
    chmod 0755 opencode
    test -x opencode || (echo "opencode binary missing after extract" >&2; ls -la; exit 1)

    runHook postInstall
  '';

  meta = {
    description = "opencode — terminal-based AI coding agent (sst/opencode)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
