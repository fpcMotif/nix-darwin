# Verifies Nix sources pass the static lint tools documented in ARCHITECTURE.md.
{ pkgs, self, ... }:

pkgs.runCommand "static-lint-test"
{
  nativeBuildInputs = [
    pkgs.deadnix
    pkgs.findutils
    pkgs.statix
  ];
  src = self;
}
  ''
    cd "$src"

    statix check . \
      --ignore 'references/**' \
      --ignore './references/**' \
      --ignore 'result*' \
      --ignore './result*'

    find . \
      -type f \
      -name '*.nix' \
      -not -path './references/*' \
      -not -path './result*' \
      -print0 \
      | xargs -0 deadnix --fail

    echo "PASS Nix sources pass statix and deadnix."
    touch $out
  ''
