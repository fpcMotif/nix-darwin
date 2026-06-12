# Reproducible OCI dev container, built entirely from the pinned nixpkgs —
# no Dockerfile, no `apt-get`/`curl | sh` drift. Exposed per Linux system as
# `packages.<system>.dev-container` (it is not part of the pkgs.martin
# overlay because images only exist for Linux platforms).
#
# Build (Linux machine or CI):    nix build .#packages.x86_64-linux.dev-container
# Build on the Mac (M-series):    enable martin.linuxBuilder, then
#                                 nix build .#packages.aarch64-linux.dev-container
# Run:                            docker load < result && docker run -it martin-dev:<tag>
#
# buildLayeredImage puts each store path in its own layer, so toolchain bumps
# only invalidate the layers that actually changed.
{ dockerTools
, bashInteractive
, cacert
, coreutils
, curl
, fd
, findutils
, git
, gnugrep
, gnused
, gnutar
, gzip
, jq
, less
, ripgrep
, tmux
, vim
, which
}:

dockerTools.buildLayeredImage {
  name = "martin-dev";
  # No explicit tag: dockerTools derives one from the image's store hash, so
  # the tag identifies exact contents instead of a mutable "latest".

  contents = [
    bashInteractive
    cacert
    coreutils
    curl
    fd
    findutils
    git
    gnugrep
    gnused
    gnutar
    gzip
    jq
    less
    ripgrep
    tmux
    vim
    which
  ];

  # Minimal writable scaffolding; images have no stdpaths by default.
  extraCommands = ''
    mkdir -p tmp root workspace
    chmod 1777 tmp
  '';

  config = {
    Cmd = [ "${bashInteractive}/bin/bash" ];
    WorkingDir = "/workspace";
    Env = [
      "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "GIT_SSL_CAINFO=${cacert}/etc/ssl/certs/ca-bundle.crt"
      "LANG=C.UTF-8"
      "PAGER=less"
    ];
    Labels = {
      "org.opencontainers.image.title" = "martin-dev";
      "org.opencontainers.image.description" = "Nix-built reproducible dev container from fpcMotif/nix-darwin";
      "org.opencontainers.image.source" = "https://github.com/fpcMotif/nix-darwin";
    };
  };
}
