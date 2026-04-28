# Compatibility shim. The active Home Manager config lives in modules/home.
{
  _module.args.currentSystemUser = "martinfan";
  imports = [ ./modules/home ];
}
