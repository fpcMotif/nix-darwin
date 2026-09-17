{ lib }:

parts:
lib.concatStringsSep "\n\n"
  (map (path: lib.removeSuffix "\n" (builtins.readFile path)) parts)
  + "\n"
