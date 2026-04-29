# jj-starship: unified Starship prompt module for Git and Jujutsu repos.
#
# Vendored from https://github.com/dmmulroy/jj-starship under ./jj-starship/.
# Bumping:
#   1. Replace ./jj-starship/{src,Cargo.toml,Cargo.lock,build.rs} from upstream
#      (e.g. via `cp -R ~/jj-starship/{src,Cargo.toml,Cargo.lock,build.rs} ./pkgs/jj-starship/`).
#   2. Bump `version` below to match the upstream Cargo.toml `[package].version`.
#   3. If new transitive crates appear in Cargo.lock, Nix will use cargoLock.lockFile
#      automatically — no separate hash to update.
{ lib
, rustPlatform
, pkg-config
, openssl
, zlib
, libgit2
, libiconv
, apple-sdk
, stdenv
, withGit ? true
,
}:

rustPlatform.buildRustPackage {
  pname = "jj-starship" + lib.optionalString (!withGit) "-no-git";
  version = "0.7.0";

  # File-set keeps closures small and avoids invalidating the build on README/AGENTS edits.
  src = lib.fileset.toSource {
    root = ./jj-starship;
    fileset = lib.fileset.unions [
      ./jj-starship/Cargo.toml
      ./jj-starship/Cargo.lock
      ./jj-starship/src
      ./jj-starship/build.rs
    ];
  };

  cargoLock.lockFile = ./jj-starship/Cargo.lock;

  buildNoDefaultFeatures = !withGit;

  nativeBuildInputs = [ pkg-config ];

  buildInputs =
    [
      openssl
      zlib
    ]
    ++ lib.optionals withGit [ libgit2 ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      apple-sdk
      libiconv
    ];

  doCheck = true;

  meta = {
    description = "Unified Git/JJ Starship prompt module optimized for latency";
    homepage = "https://github.com/dmmulroy/jj-starship";
    changelog = "https://github.com/dmmulroy/jj-starship/releases/tag/v0.7.0";
    license = lib.licenses.mit;
    mainProgram = "jj-starship";
    platforms = lib.platforms.unix;
  };
}
