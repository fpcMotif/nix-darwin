{ writeShellApplication
, coreutils
, gawk
, git
, gnugrep
, jq
, jujutsu
}:

# wt stays off runtimeInputs: the script uses it only when the workspace backend installs it.
writeShellApplication {
  name = "agent-checkout";
  runtimeInputs = [ coreutils gawk git gnugrep jq jujutsu ];
  text = builtins.readFile ../modules/home/workspace-backend/agent-checkout.sh;
}
