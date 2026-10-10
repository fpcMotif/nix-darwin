{ writeShellApplication
, coreutils
, jq
}:

# jj, git, and gh come from PATH: pushes keep the user's credential helpers,
# and the unit test can put a stub gh in front.
writeShellApplication {
  name = "jj-pr";
  runtimeInputs = [ coreutils jq ];
  text = builtins.readFile ../modules/home/jj-pr/jj-pr.sh;
}
