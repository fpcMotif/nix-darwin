{ lib
, fetchurl
, martin
,
}:

let
  version = "1.6.8815";
in
martin.mkAppFromZip {
  pname = "bettermouse";
  inherit version;
  appName = "BetterMouse.app";

  src = fetchurl {
    url = "https://better-mouse.com/wp-content/uploads/BetterMouse.${version}.zip";
    hash = "sha256-jDZrv2DpHgrc7fFFNm3yL9h/OYbJs85yhBZ99WTVn04=";
  };

  meta = {
    description = "Customizable mouse driver for macOS";
    homepage = "https://better-mouse.com/";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
