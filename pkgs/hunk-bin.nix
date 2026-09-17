# Hunk (binary `hunk`) — review-first terminal diff viewer for agent-authored
# changesets (modem-dev/hunk). Agents steer an open window with
# `hunk session ...` and load its bundled skill from `hunk skill path`;
# CLAUDE.md's Git section routes human review of agent changes here.
#
# Why a prebuilt release and not nixpkgs `hunk`: nixpkgs compiles it with
# `bun build --compile`, and the cached aarch64-darwin output (0.20.1) dies
# with SIGKILL on launch here (`codesign --verify`: "code or signature have
# been modified"). The upstream release asset is the same kind of Bun binary
# but launches, and it is what `hunk.dev/install.sh` and Homebrew ship.
#
# Layout: the tarball is kept whole under libexec because the binary resolves
# its real path and looks for `skills/<name>/SKILL.md` beside itself; bin/hunk
# is a symlink into it. Stripping would rewrite the Mach-O and break the
# signature, so the bytes stay as downloaded.
#
# Bumping: scripts/update-hunk.sh polls the GitHub releases API (stable
# channel, so betas are skipped) and refreshes the hash.

{ lib
, stdenvNoCC
, fetchurl
, gnutar
}:

let
  version = "0.22.0";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/modem-dev/hunk/releases/download/v${version}/hunkdiff-darwin-arm64.tar.gz";
      hash = "sha256-D1Yv3WqzRsfZHEdV49lAn84dL3Lage/VK9t+RDHEsF4=";
    };
  };

  source = sources.${stdenvNoCC.hostPlatform.system}
    or (throw "hunk-bin: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "hunk-bin";
  inherit version;

  src = fetchurl { inherit (source) url hash; };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [ gnutar ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec"
    tar -xzf "$src" -C "$out/libexec"
    mv "$out/libexec"/hunkdiff-* "$out/libexec/hunk"
    chmod 0755 "$out/libexec/hunk/hunk"
    test -f "$out/libexec/hunk/skills/hunk-review/SKILL.md" \
      || (echo "hunk-bin: skills missing after extract" >&2; ls -R "$out/libexec" >&2; exit 1)
    mkdir -p "$out/bin"
    ln -s ../libexec/hunk/hunk "$out/bin/hunk"

    runHook postInstall
  '';

  meta = {
    description = "Hunk — terminal diff viewer for agentic changesets, prebuilt release";
    homepage = "https://github.com/modem-dev/hunk";
    changelog = "https://github.com/modem-dev/hunk/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "hunk";
    platforms = builtins.attrNames sources;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
