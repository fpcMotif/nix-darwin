{ writeShellApplication, bun, git, nodejs-slim_26 }:

writeShellApplication {
  name = "calldiff";
  runtimeInputs = [ bun git nodejs-slim_26 ];
  text = ''
    exec bunx calldiff@0.5.0 "$@"
  '';
}
