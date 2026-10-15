# Evaluates feature modules against the Agent surface catalog alone, without
# a full Home Manager configuration. Definitions for options outside the
# catalog (programs.*, home.file, ...) are dropped, so a test reads only
# what the module contributes to the catalog and its assertions.
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
        _module.check = false;
        _module.args.pkgs = pkgs;
      };
    }
  ] ++ modules;
}).config
