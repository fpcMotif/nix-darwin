{ pkgs, ... }:

{
  home.packages = [ pkgs.martin.recall ];
  martin.agentSurface.guideSections.startup = [ ./guide.md ];
}
