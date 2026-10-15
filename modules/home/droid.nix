{ pkgs, config, lib, ... }:

{
  # Keep a stable user-PATH symlink so macOS TCC grants survive store-path updates.
  home.file.".local/bin/droid".source = pkgs.martin.droid + "/bin/droid";

  # Make sure ~/.factory exists so the CLI's first-run flow doesn't fight
  # macOS sandboxing in unexpected directories.
  home.activation.droidStateDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "${config.home.homeDirectory}/.factory"
  '';
}
