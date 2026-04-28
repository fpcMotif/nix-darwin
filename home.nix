# Compatibility shim. The active Home Manager config lives in modules/home.
{ pkgs, ... }:
{
  _module.args.currentSystemUser = "martinfan";
  _module.args.currentSystemUserHome =
    if pkgs.stdenv.isDarwin then "/Users/martinfan" else "/home/martinfan";
  imports = [ ./modules/home ];
}
