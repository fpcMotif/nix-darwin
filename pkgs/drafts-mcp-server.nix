# drafts-mcp-server — @agiletortoise/drafts-mcp-server (Drafts.app MCP server,
# pure AppleScript bridge) with local reliability patches baked in. These
# patches previously lived as hand-edits inside the bun global install's
# dist/ and were wiped by every `bun update -g`.
#
# The npm tarball ships prebuilt dist/*.js (no build step). We install it with
# its runtime deps via importNpmLock, then apply the patches on top:
#
#   patches/applescript-watchdog-and-global-lock.patch
#     20s osascript watchdog (DRAFTS_MCP_OSASCRIPT_TIMEOUT_MS), 8MB output
#     cap (DRAFTS_MCP_MAX_OUTPUT_BYTES), and a global filesystem lock that
#     serializes AppleScript across all server instances
#     (DRAFTS_MCP_LOCK_TIMEOUT_MS).
#   patches/drafts-bulk-gate-and-result-cap.patch
#     Bulk enumeration (get_drafts / search / get_tag / get_workspace_drafts)
#     throws unless DRAFTS_MCP_ALLOW_BULK=1 — `every draft whose ...` makes
#     Cocoa Scripting walk the whole ~91k-draft library and wedges Drafts'
#     main thread. 200-result cap (DRAFTS_MCP_MAX_RESULTS); NaN-date guard.
#   patches/index-bulk-gate-and-stdin-eof-exit.patch
#     Bulk tools hidden from tools/list unless DRAFTS_MCP_ALLOW_BULK=1, and
#     exit on stdin EOF/close so stdio servers no longer outlive their client
#     and pile up as orphans.
#
# Version bumps fail loudly by design: if a new upstream tarball drifts under
# the patches, `patch` errors at build time, forcing a conscious re-diff
# instead of silently shipping unpatched code again.
#
# Bumping (no hash dance — importNpmLock derives deps from the lockfile):
#   1. find current version: npm view @agiletortoise/drafts-mcp-server version
#   2. update ./drafts-mcp-server/package.json and `version` below.
#   3. regenerate the lock:
#        (cd ~/nix-config/pkgs/drafts-mcp-server && npm install --package-lock-only)
#   4. nix build .#martin.drafts-mcp-server   # re-diff patches/ if this fails

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
