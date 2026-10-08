{ lib
, buildGo127Module
, fetchFromGitHub
, versionCheckHook
,
}:

buildGo127Module (finalAttrs: {
  pname = "typescript";
  version = "7.1.0-dev";

  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "typescript";
    rev = "ec47d33c23e464a17cdf2475632cba629bee8763";
    hash = "sha256-TdD7/ywGezZGdYMrHMk9OnKnyzLWGsQtjukbr7xxcjk=";
  };

  modRoot = "tsc";

  vendorHash = "sha256-XmN6VfL922FqKUHRnBfGTuEUFbPELf8F6JINVMTz1/w=";

  tags = [ "noembed" ];

  ldflags = [
    "-s"
    "-w"
  ];

  env.CGO_ENABLED = 0;
  env.GOWORK = "off";

  subPackages = [
    "cmd/tsc"
  ];

  # When built with the "noembed" tag, the executable must be under "lib/${pname}/" to resolve its paths.
  postInstall = ''
    lib_dir="$out/lib/${finalAttrs.pname}"
    mkdir -p "$lib_dir"
    cp -r internal/bundled/libs/. "$lib_dir"

    mv "$out/bin/tsc" "$lib_dir/tsc"
    ln -s "$lib_dir/tsc" "$out/bin/tsc"
  '';

  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  doInstallCheck = true;

  meta = {
    description = "Superset of JavaScript that compiles to clean JavaScript output";
    homepage = "https://www.typescriptlang.org/";
    license = lib.licenses.asl20;
    mainProgram = "tsc";
  };
})
