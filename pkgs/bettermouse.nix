{ lib
, fetchurl
, martin
,
}:

let
  version = "1.6.8888";
in
martin.mkAppFromZip {
  pname = "bettermouse";
  inherit version;
  appName = "BetterMouse.app";

  src = fetchurl {
    url = "https://better-mouse.com/wp-content/uploads/BetterMouse.${version}.zip";
    hash = "sha256-IkSTBu5PvrE5j5GfmCCexXUHObKQVUKy7TSE51bFHT4=";
  };

  meta = {
    description = "Customizable mouse driver for macOS";
    homepage = "https://better-mouse.com/";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
