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
  # Omit tag so dockerTools derives an immutable tag from the store hash.
  name = "martin-dev";

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
