{ lib
, stdenvNoCC
, fetchurl
}:

let
  version = "0.18.0-dev.852+efa5bfa9b";

  sources = {
    "aarch64-darwin" = {
      url = "https://ziglang.org/builds/zig-aarch64-macos-${version}.tar.xz";
      hash = "sha256-7OLzsN9MgQoE4dquoRP+xBr6BCBbp+ESFPH2qMeYOJ0=";
    };
    "x86_64-darwin" = {
      url = "https://ziglang.org/builds/zig-x86_64-macos-${version}.tar.xz";
      hash = "sha256-V1wyJTG9jYC7HN7LVpZB/I67GnaOV9VEurEe6HaJe6w=";
    };
    "aarch64-linux" = {
      url = "https://ziglang.org/builds/zig-aarch64-linux-${version}.tar.xz";
      hash = "sha256-0TKXTZyRMO8H4v8ZDb5kOo6Rpl9dD4DtxO6NXRyz5ag=";
    };
    "x86_64-linux" = {
      url = "https://ziglang.org/builds/zig-x86_64-linux-${version}.tar.xz";
      hash = "sha256-0oUNuObukb8sDxmzNUqN6Z+j8xmLTeoVfpWgaAD9Cr8=";
    };
  };

  system = stdenvNoCC.hostPlatform.system;
  source = sources.${system} or (throw "zig-dev-bin: unsupported system ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "zig";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/lib/zig"
    cp -r * "$out/lib/zig/"
    ln -s "$out/lib/zig/zig" "$out/bin/zig"
    runHook postInstall
  '';

  meta = {
    description = "General-purpose programming language and toolchain for maintaining robust, optimal, and reusable software (development master build)";
    homepage = "https://ziglang.org/";
    license = lib.licenses.mit;
    platforms = builtins.attrNames sources;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "zig";
  };
}
