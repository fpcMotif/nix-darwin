{ lib
, fetchurl
, martin
,
}:

let
  version = "1.6.8812";
in
martin.mkAppFromZip {
  pname = "bettermouse";
  inherit version;
  appName = "BetterMouse.app";

  src = fetchurl {
    url = "https://better-mouse.com/wp-content/uploads/BetterMouse.${version}.zip";
    hash = "sha256-KsytFwiJ82Laj5OD77Rzjl+riNj1NF9ONW7VLEc3LeY=";
  };

  meta = {
    description = "Customizable mouse driver for macOS";
    homepage = "https://better-mouse.com/";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
