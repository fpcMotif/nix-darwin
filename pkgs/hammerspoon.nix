{ lib
, fetchurl
, martin
,
}:

let
  version = "1.1.1";
in
martin.mkAppFromZip {
  pname = "hammerspoon";
  inherit version;
  appName = "Hammerspoon.app";

  src = fetchurl {
    url = "https://github.com/Hammerspoon/hammerspoon/releases/download/${version}/Hammerspoon-${version}.zip";
    hash = "sha256-EbsckPr1Qn83x71P5+q5d0rkPh1csCDFswiNrDKEnvo=";
  };

  meta = {
    description = "Powerful macOS desktop automation with Lua";
    homepage = "https://www.hammerspoon.org/";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" "x86_64-darwin" ];
  };
}
