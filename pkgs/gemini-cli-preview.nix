# gemini-cli @preview — fresh buildNpmPackage call.
#
# Why a separate file (not overrideAttrs): nixpkgs's gemini-cli derivation is
# defined as `buildNpmPackage (finalAttrs: { ... })`. The inner `finalAttrs`
# closes over the original `pname`/`version`, so an `overrideAttrs` at the
# outer level fails to propagate the new values into the npmDeps store-path
# naming — the build then fails verifying the package-lock.json against a
# stale `gemini-cli-0.38.2-npm-deps` cache. Calling buildNpmPackage afresh
# avoids that closure issue entirely.
#
# This file is a near-verbatim copy of
#   nixpkgs/pkgs/by-name/ge/gemini-cli/package.nix
# with version + hashes pointed at the @preview dist-tag. Bumping:
#   1. find current preview:
#        curl -s https://registry.npmjs.org/@google/gemini-cli \
#          | jq -r '."dist-tags".preview'
#   2. update `version` below.
#   3. update src `hash`:
#        H=$(nix-prefetch-url --unpack \
#          https://github.com/google-gemini/gemini-cli/archive/refs/tags/v<VER>.tar.gz)
#        nix hash convert --to sri --hash-algo sha256 "$H"
#   4. update `npmDepsHash` via the lib.fakeHash dance
#      (set to lib.fakeHash, build, copy "got: sha256-…" back).

{ lib
, stdenv
, buildNpmPackage
, fetchFromGitHub
, jq
, pkg-config
, makeWrapper
, clang_20
, libsecret
, ripgrep
, nodejs_22
,
}:

buildNpmPackage (finalAttrs: {
  pname = "gemini-cli-preview";
  version = "0.40.0-preview.4";

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${finalAttrs.version}";
    hash = "sha256-7M4wgqHArtXZItgnfzP0k05HGbRuYj2jX6JFdt8ANkA=";
  };

  nodejs = nodejs_22;

  npmDepsHash = "sha256-gBijX5/r8vjrMBkM0cVVkcZm4CIg3mkPswQGeyG2LWw=";

  dontPatchElf = stdenv.isDarwin;

  nativeBuildInputs = [
    jq
    pkg-config
    makeWrapper
  ]
  ++ lib.optionals stdenv.isDarwin [ clang_20 ];

  buildInputs = [
    ripgrep
    libsecret
  ];

  preConfigure = ''
    mkdir -p packages/generated
    echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" > packages/generated/git-commit.ts
  '';

  postPatch = ''
    # Remove node-pty dependency from package.json (top-level + core)
    ${jq}/bin/jq 'del(.optionalDependencies."node-pty")' package.json > package.json.tmp && mv package.json.tmp package.json
    ${jq}/bin/jq 'del(.optionalDependencies."node-pty")' packages/core/package.json > packages/core/package.json.tmp && mv packages/core/package.json.tmp packages/core/package.json

    # Pin the ripgrep path so SearchText doesn't fall back to a dynamically
    # linked rg without its required libraries.
    substituteInPlace packages/core/src/tools/ripGrep.ts \
      --replace-fail "await ensureRgPath();" "'${lib.getExe ripgrep}';"

    # Disable auto-update at compile time (Nix manages versions).
    sed -i '/enableAutoUpdate:/,/default: true/ s/default: true/default: false/' packages/cli/src/config/settingsSchema.ts
    sed -i '/enableAutoUpdateNotification:/,/default: true/ s/default: true/default: false/' packages/cli/src/config/settingsSchema.ts
    substituteInPlace packages/cli/src/utils/handleAutoUpdate.ts \
      --replace-fail "if (!settings.merged.general.enableAutoUpdateNotification) {" "if (false) {" \
      --replace-fail "settings.merged.general.enableAutoUpdate," "false," \
      --replace-fail "!settings.merged.general.enableAutoUpdate" "!false"
  '';

  disallowedReferences = [
    finalAttrs.npmDeps
    finalAttrs.nodejs.python
  ];

  npmBuildScript = "bundle";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share}
    cp -r bundle $out/share/gemini-cli

    # Keep only optionalDependencies (e.g. @lydell/node-pty); regular deps
    # are bundled into gemini.js by esbuild.
    jq '.dependencies = {} | del(.devDependencies) | del(.workspaces)' package.json > package.json.tmp && mv package.json.tmp package.json
    npm prune --omit=dev
    rm -rf node_modules/.bin

    # gyp-mac-tool has a python shebang that gets patched, leaking python
    # into the closure — strip the build artifacts.
    find node_modules -path "*/build/*" -type f -not -name "*.node" -delete
    find node_modules -type d -empty -delete

    cp -r node_modules $out/share/gemini-cli/

    rm -f $out/share/gemini-cli/docs/CONTRIBUTING.md

    makeWrapper ${nodejs_22}/bin/node $out/bin/gemini \
      --add-flags "$out/share/gemini-cli/gemini.js" \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  meta = {
    description = "AI agent that brings the power of Gemini directly into your terminal (preview channel)";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    mainProgram = "gemini";
    platforms = lib.platforms.unix;
  };
})
