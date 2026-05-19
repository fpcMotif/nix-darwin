{ lib
, fetchurl
, martin
,
}:

let
  version = "252.4.3485";
in
martin.mkAppFromDmg {
  pname = "dropbox";
  inherit version;
  appName = "Dropbox.app";

  src = fetchurl {
    url = "https://edge.dropboxstatic.com/dbx-releng/client/Dropbox%20${version}.dmg";
    name = "Dropbox.dmg";
    hash = "sha256-DuAU6+w1ir2pEd5I5HPJIFTFSRN9edQ4cGZL1S63XYc=";
  };

  meta = {
    description = "Dropbox client";
    homepage = "https://www.dropbox.com";
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
    license = lib.licenses.unfree;
  };
}
