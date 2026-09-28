{ writeShellApplication
, ast-grep
, coreutils
, findutils
, git
, gnugrep
, jq
}:

writeShellApplication {
  name = "doc-lock";
  runtimeInputs = [ ast-grep coreutils findutils git gnugrep jq ];
  excludeShellChecks = [ "SC2016" ];
  text = builtins.readFile ../modules/home/doc-lock/doc-lock.sh;
}
