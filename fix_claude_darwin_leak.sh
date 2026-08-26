sed -i 's/home.activation.codexLspConfig = hm.dag.entryAfter \[ "writeBoundary" \] '"''"'/home.activation.codexLspConfig = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (hm.dag.entryAfter \[ "writeBoundary" \] '"''"'/' modules/home/lsp.nix
sed -i 's/    fi\n  '"''"';/    fi\n  '"''"');/' modules/home/lsp.nix
