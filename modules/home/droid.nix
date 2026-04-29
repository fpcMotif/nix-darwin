{ pkgs, config, lib, ... }:

# Factory AI Droid CLI. Stable user-PATH symlink (TCC pattern) plus a seeded
# config dir so the first `droid` invocation has a place to stash auth state
# without prompting for a path.

{
  home.file.".local/bin/droid".source = pkgs.martin.droid + "/bin/droid";

  # Make sure ~/.factory exists so the CLI's first-run flow doesn't fight
  # macOS sandboxing in unexpected directories.
  home.activation.droidStateDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/.factory"
  '';
}
