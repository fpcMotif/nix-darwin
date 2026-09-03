final: _prev:

{
  direnv = _prev.direnv.overrideAttrs (_old: {
    doCheck = false;
  });

  # tmux 3.7 added a configure check that REFUSES to build on darwin unless
  # jemalloc is explicitly opted in or out:
  #   "macOS calloc(3) appears not to correctly zero allocations in some
  #    circumstances; ... configuring with --enable-jemalloc is recommended.
  #    To build without anyway, use --disable-jemalloc"
  # nixpkgs' pkgs/by-name/tm/tmux/package.nix passes neither, so every darwin
  # build of tmux >=3.7 dies at configure — which takes home-manager-path and
  # therefore the WHOLE `darwin-rebuild switch` down with it. Upstream has no
  # fix as of nixpkgs c8f9065 (2026-08-22).
  #
  # Opt IN rather than out: the calloc bug the check warns about is real, and
  # jemalloc is cached for aarch64-darwin, so this costs nothing.
  #
  # Darwin-only: the configure check that hard-fails is guarded by
  # `platform = darwin` upstream, and Linux tmux builds fine untouched — no
  # reason to drag jemalloc into the Linux hosts' closure.
  # Drop this override once nixpkgs' own package sets a jemalloc flag.
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

  martin = {
    mkAppFromZip = final.callPackage ./lib/mk-app-from-zip.nix { };

    hammerspoon = final.callPackage ./hammerspoon.nix { };
    mole = final.callPackage ./mole.nix { };
    sf-mono = final.callPackage ./sf-mono.nix { };
    sf-symbols = final.callPackage ./sf-symbols.nix { };
    squirrel = final.callPackage ./squirrel.nix { };

    bun-canary-bin = final.callPackage ./bun-canary-bin.nix { };
    drafts-mcp-server = final.callPackage ./drafts-mcp-server.nix { };
    fff-mcp = final.callPackage ./fff-mcp.nix { };
    nub = final.callPackage ./nub.nix { };
    oh-my-pi = final.callPackage ./oh-my-pi.nix { };
    pi-coding-agent = final.callPackage ./pi-coding-agent.nix { };
    sourcegraph-amp = final.callPackage ./sourcegraph-amp.nix { };
    droid = final.callPackage ./droid.nix { };
    opencode = final.callPackage ./opencode.nix { };
    zed-nightly-bin = final.callPackage ./zed-nightly-bin.nix { };
  };
}
