{ lib
, fetchurl
, martin
,
}:

let
  version = "1.104.17";
in
martin.mkAppFromDmg {
  pname = "raycast";
  inherit version;
  appName = "Raycast.app";

  src = fetchurl {
    url = "https://releases.raycast.com/releases/${version}/download?build=universal";
    name = "Raycast.dmg";
    hash = "sha256-vX1LYxiZ48H5fuFXKA+EJ62on3Fcb+e7obpabSQqOqE=";
  };

  meta = {
    description = "Raycast launcher";
    homepage = "https://www.raycast.com";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
