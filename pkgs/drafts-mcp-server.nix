{ lib
, buildNpmPackage
, importNpmLock
, nodejs-slim_26
,
}:

buildNpmPackage {
  pname = "drafts-mcp-server";
  version = "1.0.12";

  src = ./drafts-mcp-server;

  npmDeps = importNpmLock {
    npmRoot = ./drafts-mcp-server;
  };

  npmConfigHook = importNpmLock.npmConfigHook;

  dontNpmBuild = true;

  installPhase = ''
        runHook preInstall

        pkgroot="node_modules/@agiletortoise/drafts-mcp-server"
        for p in ${./drafts-mcp-server/patches}/*.patch; do
          echo "applying $p" >&2
          patch -p1 -d "$pkgroot" < "$p"
        done

        mkdir -p $out/libexec/drafts-mcp-server $out/bin
        cp -R node_modules $out/libexec/drafts-mcp-server/

        server_js="$out/libexec/drafts-mcp-server/node_modules/@agiletortoise/drafts-mcp-server/dist/index.js"
        cli_js="$out/libexec/drafts-mcp-server/node_modules/@agiletortoise/drafts-mcp-server/dist/cli.js"
        for f in "$server_js" "$cli_js"; do
          if [ ! -f "$f" ]; then
            printf '%s\n' "drafts-mcp-server: expected file not found: $f" >&2
            printf '%s\n' "The @agiletortoise/drafts-mcp-server npm layout may have changed; check pkgs/drafts-mcp-server/package-lock.json." >&2
            exit 1
          fi
        done

        cat > $out/bin/drafts-mcp-server <<EOF
    #!/bin/sh
    exec ${nodejs-slim_26}/bin/node "$server_js" "\$@"
    EOF
        chmod 755 $out/bin/drafts-mcp-server

        cat > $out/bin/drafts <<EOF
    #!/bin/sh
    exec ${nodejs-slim_26}/bin/node "$cli_js" "\$@"
    EOF
        chmod 755 $out/bin/drafts

        runHook postInstall
  '';

  meta = {
    description = "MCP server for the Drafts app via AppleScript, with local watchdog/lock/bulk-gate patches";
    homepage = "https://github.com/agiletortoise/drafts-mcp-server";
    license = lib.licenses.mit;
    mainProgram = "drafts-mcp-server";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
}
