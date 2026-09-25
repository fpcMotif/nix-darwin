{ config, lib, pkgs, ... }:

let
  package = pkgs.martin.dojjo-bin;
  toml = pkgs.formats.toml { };

  # dojjo prints static wrapper and completion scripts. Rendering them at build
  # time skips two djo forks on every shell start and pins them to this djo.
  # The wrapper defines `djo` only, so it never competes with `wt` or `jj`.
  zshInit = pkgs.runCommand "dojjo-init.zsh" { } ''
    ${lib.getExe package} shell init zsh > $out
    ${lib.getExe package} shell completion zsh >> $out
  '';
in
lib.mkIf (config.martin.development.workspaceBackend == "dojjo") {
  home.packages = [ package ];

  # Worktrunk's config.toml is absent under this backend, so every key dojjo
  # needs is declared here rather than inherited through its wt.toml fallback.
  xdg.configFile."dojjo/config.toml".source = toml.generate "dojjo-config.toml" {
    # Worktrunk's sibling layout. dojjo renders repo_path from the workspace
    # it runs in, so creating from a secondary workspace nests the name.
    workspace-path = "{{ repo_path }}/../{{ repo }}.{{ branch | sanitize }}";

    # Merges never push or delete a workspace directory. Cleanup stays a
    # deliberate `jj workspace forget` plus a manual delete.
    merge = {
      push = false;
      remove = false;
    };
  };

  # Default order 1000 runs after compinit (570), so `compdef _djo djo` works.
  programs.zsh.initContent = ''
    source ${zshInit}
  '';
}
