# Minimal test helpers used by the local test suite.
{ pkgs, ... }:

rec {
  # Build a derivation that succeeds iff `condition` is true.
  # If `condition` is false, the build fails and prints `message`.
  assertTest = name: condition: message:
    pkgs.runCommand "test-${name}" { } (
      if condition then ''
        echo "PASS ${name}"
        touch $out
      '' else ''
        echo "FAIL ${name}"
        echo "${message}"
        exit 1
      ''
    );

  # Bundle several test derivations into one aggregate derivation.
  testSuite = suiteName: tests:
    pkgs.runCommand "test-suite-${suiteName}"
      {
        passthru.tests = tests;
        buildInputs = tests;
      }
      ''
        echo "PASS test-suite ${suiteName} (${toString (builtins.length tests)} cases)"
        touch $out
      '';
}
