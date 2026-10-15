{ lib }:

{ pkgs, modules }:
(lib.evalModules {
  modules = [
    ../../modules/home/agent-surface.nix
    {
      options.assertions = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
      };
      config = {
        # Drop definitions outside the catalog (programs.*, home.file, ...).
        _module.check = false;
        _module.args.pkgs = pkgs;
      };
    }
  ] ++ modules;
}).config
