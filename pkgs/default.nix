final: _prev:

{
  direnv = _prev.direnv.overrideAttrs (_old: {
    doCheck = false;
  });
  # nixpkgs' Node 26 test suite currently fails in the Linux Nix sandbox on
  # test-fs-cp-async-file-modes. Keep the rest of the suite enabled; remove
  # this workaround when nixpkgs carries the fix.
  nodejs-slim_26 =
    if final.stdenv.hostPlatform.isLinux then
      _prev.nodejs-slim_26.overrideAttrs
        (old: {
          checkFlags = map
            (flag:
              if final.lib.hasPrefix "CI_SKIP_TESTS=" flag then
                "${flag},test-fs-cp-async-file-modes"
              else
                flag
            )
            (old.checkFlags or [ ]);
        })
    else
      _prev.nodejs-slim_26;

  # tmux >= 3.7 refuses to configure on Darwin unless jemalloc is explicitly
  # enabled or disabled, and nixpkgs passes neither flag.
  tmux =
    if final.stdenv.hostPlatform.isDarwin then
      _prev.tmux.overrideAttrs
        (old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ final.jemalloc ];
          configureFlags = (old.configureFlags or [ ]) ++ [ "--enable-jemalloc" ];
        })
    else
      _prev.tmux;

  codex = final.callPackage ./codex.nix { };
  typescript = final.callPackage ./typescript.nix { };
  tsrs = final.callPackage ./tsrs-bin.nix { };


  martin = {
    mkAppFromZip = final.callPackage ./lib/mk-app-from-zip.nix { };

    hammerspoon = final.callPackage ./hammerspoon.nix { };
    mole = final.callPackage ./mole.nix { };
    sf-mono = final.callPackage ./sf-mono.nix { };
    sf-symbols = final.callPackage ./sf-symbols.nix { };
    squirrel = final.callPackage ./squirrel.nix { };

    # rust-lang's prebuilt stable via rust-overlay, which carries a release
    # within a day while nixpkgs trails by weeks. One bundle keeps cargo,
    # rustc, clippy, rustfmt, and rust-analyzer on the same version.
    rust-toolchain = final.rust-bin.stable.latest.minimal.override {
      extensions = [ "clippy" "rustfmt" "rust-src" "rust-analyzer" ];
    };

    bun-canary-bin = final.callPackage ./bun-canary-bin.nix { };
    calldiff = final.callPackage ./calldiff.nix { };
    doc-lock = final.callPackage ./doc-lock.nix { };
    doc-lock-extension = final.replaceVars ../modules/home/doc-lock/agent-extension.ts {
      docLock = final.lib.getExe final.martin.doc-lock;
    };
    dojjo-bin = final.callPackage ./dojjo-bin.nix { };
    drafts-mcp-server = final.callPackage ./drafts-mcp-server.nix { };
    fff-mcp = final.callPackage ./fff-mcp.nix { };
    hk-bin = final.callPackage ./hk-bin.nix { };
    hunk-bin = final.callPackage ./hunk-bin.nix { };
    jj-pr = final.callPackage ./jj-pr.nix { };
    nub = final.callPackage ./nub.nix { };
    oh-my-pi = final.callPackage ./oh-my-pi.nix { };
    pi-coding-agent = final.callPackage ./pi-coding-agent.nix { };
    sourcegraph-amp = final.callPackage ./sourcegraph-amp.nix { };
    droid = final.callPackage ./droid.nix { };
    opencode = final.callPackage ./opencode.nix { };
    uv-bin = final.callPackage ./uv-bin.nix { };
    zed-nightly-bin = final.callPackage ./zed-nightly-bin.nix { };
  };
}
