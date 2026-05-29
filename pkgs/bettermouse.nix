{ lib
, fetchurl
, martin
,
}:

let
  version = "1.6.8830";
in
martin.mkAppFromZip {
  pname = "bettermouse";
  inherit version;
  appName = "BetterMouse.app";

  src = fetchurl {
    url = "https://better-mouse.com/wp-content/uploads/BetterMouse.${version}.zip";
    hash = "sha256-YKF5r5ftJ8OaIZGtSvLF+Q9bn5QBQTZd2Jc089U3odk=";
  };

  meta = {
    description = "Customizable mouse driver for macOS";
    homepage = "https://better-mouse.com/";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
