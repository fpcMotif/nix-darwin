{ config, lib, pkgs, ... }:

{
  options.martin.development.workspaceBackend = lib.mkOption {
    type = lib.types.enum [ "worktrunk" "dojjo" ];
    default = "worktrunk";
    example = "dojjo";
    description = ''
      The tool that creates parallel checkouts beside a repository.

      `worktrunk` installs `wt`, which manages Git worktrees.
      `dojjo` is experimental and installs `djo`, which manages JJ workspaces.
      It is packaged for aarch64-darwin only.

      The choice selects the package, its configuration, its Zsh integration,
      the matching agent guidance, and the Claude Worktrunk activity hooks.
      Changing it never converts repositories or touches existing checkouts.
      See docs/workspace-backends.md.
    '';
  };

  config.assertions = [
    {
      assertion = config.martin.development.workspaceBackend != "dojjo"
        || lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.martin.dojjo-bin;
      message = ''
        martin.development.workspaceBackend = "dojjo" is experimental and
        packaged for ${lib.concatStringsSep ", " pkgs.martin.dojjo-bin.meta.platforms} only,
        not ${pkgs.stdenv.hostPlatform.system}. Use "worktrunk" on this host.
      '';
    }
  ];
}
