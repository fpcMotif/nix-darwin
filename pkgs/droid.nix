{ lib
, stdenvNoCC
, fetchurl
, autoPatchelfHook
, darwin
}:

let
  version = "0.174.0";

  # Factory publishes per-platform binary-only npm packages. These URLs are pinned to
  # a released build and mapped by system so we install the correct native executable
  # for each platform this flake supports.
  sources = {
    "aarch64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
      hash = "sha256-R3LwiWG03D+i4ViMFT1dCQVK0MK5eUb9y1M0zeB07K4=";
    };
    "x86_64-darwin" = {
      url = "https://registry.npmjs.org/@factory/cli-darwin-x64-baseline/-/cli-darwin-x64-baseline-${version}.tgz";
      hash = "sha256-q3NXomAc5Wd1JTBA4plpx98PekmgoL/lKEkr5O9s/cw=";
    };
    "aarch64-linux" = {
      url = "https://registry.npmjs.org/@factory/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
      hash = "sha256-r96GfuICL4TdLYC+Tfs1OW8XjqGDkO9lJ8ZHEgY8Eps=";
    };
    "x86_64-linux" = {
      url = "https://registry.npmjs.org/@factory/cli-linux-x64-baseline/-/cli-linux-x64-baseline-${version}.tgz";
      hash = "sha256-uR7ehF+p6hbf6YTTGrYzwu4MIM7RVRwrkI7BD0ci7qg=";
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
    # Factory ships the binary with a `linker-signed` ad-hoc signature that
    # macOS only fixes up on a writable volume. From the read-only Nix store the
    # signature stays invalid and arm64 AMFI SIGKILLs droid the instant it
    # launches. This hook replaces it with a complete (sealed) ad-hoc signature
    # during fixup so it runs from the store.
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
