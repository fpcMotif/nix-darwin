# Verifies all Nix files in the flake source are formatted with nixpkgs-fmt.
{ system, pkgs, lib, self, ... }:

let
  helpers = import ../lib/assertions.nix { inherit pkgs lib; };
  formatter = self.formatter.${system} or null;
  formatterName =
    if formatter == null then ""
    else if formatter ? pname then formatter.pname
    else if formatter ? name then formatter.name
    else "";
  formatterChecks = helpers.testSuite "formatter-wiring" [
    (helpers.assertTest "formatter-is-configured"
      (formatter != null)
      "flake should expose formatter.${system}")

    (helpers.assertTest "formatter-is-nixpkgs-fmt"
      (lib.hasInfix "nixpkgs-fmt" formatterName)
      "formatter.${system} should be nixpkgs-fmt")

    (helpers.assertTest "formatter-evaluates"
      (let r = builtins.tryEval (toString formatter.drvPath); in r.success && r.value != "")
      "formatter.${system} should evaluate to a derivation")
  ];

  formatCheck = pkgs.runCommand "format-test"
    {
      nativeBuildInputs = [ pkgs.nixpkgs-fmt ];
      src = self;
    }
    ''
      cd "$src"
      if ! nixpkgs-fmt --check $(find . -type f -name '*.nix' -not -path './result*' -not -path './references/*' -not -path './.claude/*'); then
        echo ""
        echo "FAIL Some Nix files are not formatted."
        echo "Run: nix fmt"
        exit 1
      fi
      echo "PASS All Nix files are formatted with nixpkgs-fmt."
      touch $out
    '';
in
helpers.testSuite "format" [
  formatterChecks
  formatCheck
]
