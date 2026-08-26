sed -i 's/"Bash(darwin-rebuild:\*)"/lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "Bash(darwin-rebuild:\*)"/' modules/home/claude.nix
sed -i 's/"Bash(xcrun:\*)"/lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "Bash(xcrun:\*)"/' modules/home/claude.nix
