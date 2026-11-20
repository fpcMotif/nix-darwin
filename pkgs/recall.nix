{ writeShellApplication
, coreutils
, gawk
, jq
, ripgrep
}:

writeShellApplication {
  name = "recall";
  runtimeInputs = [ coreutils gawk jq ripgrep ];
  text = builtins.readFile ../modules/home/recall/recall.sh;
}
