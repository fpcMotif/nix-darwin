{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
, darwin
}:

let
  version = "0.245.0";

  # Factory publishes per-platform binary-only npm packages. These URLs are pinned to
  # a released build and mapped by system so we install the correct native executable
  # for each platform this flake supports.
  sources = {
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
      hash = "sha256-xZ10rbo6TEVSy+H+IQf/moyxAvJIDx0YThSKG/vJJqQ=";
    };
    "x86_64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-x64-baseline/-/cli-darwin-x64-baseline-${version}.tgz";
      hash = "sha256-23/SxQAu+Rf5XZ3I7Sf6d5kMWU3wCW4KmWoBlek9x/g=";
    };
    "aarch64-linux" = {
      url = "https://registry.npmjs.org/@factory/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
      hash = "sha256-s1HLWC788EXXdeBSJKdbf6U9ZbyRXUzf+hSBV7w7cAE=";
    };
    "x86_64-linux" = {
      url = "https://registry.npmjs.org/@factory/cli-linux-x64-baseline/-/cli-linux-x64-baseline-${version}.tgz";
      hash = "sha256-k/Ino4XDxK9q7lWA2gU7g0tJq9ILLLOYV0gYgD4mjVs=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "Unsupported platform for martin droid package: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "droid";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ] ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [
    # Factory ships a linker-signed binary that arm64 AMFI SIGKILLs when launched
    # from the read-only Nix store. Re-sign it with a sealed ad-hoc signature.
    darwin.autoSignDarwinBinariesHook
  ];

  # droid is a ~110MB Bun single-file executable: stripping can corrupt the JS
  # payload appended after the Mach-O image, so leave the bytes intact (and
  # keep the signature the re-sign hook applies valid).
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin"
    install -m 755 "package/bin/droid" "$out/bin/droid"

    runHook postInstall
  '';

  meta = {
    description = "Factory Droid CLI";
    homepage = "https://factory.ai";
    license = lib.licenses.unfree;
    mainProgram = "droid";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
