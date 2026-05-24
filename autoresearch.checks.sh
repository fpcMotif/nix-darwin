#!/usr/bin/env bash
set -euo pipefail

# Correctness gate. Keep this focused: formatting and the checks most likely to
# catch Nix module regressions from readability/documentation changes.
nix build --no-link \
  '.#checks.aarch64-darwin.unit-format' \
  '.#checks.aarch64-darwin.unit-mksystem' \
  '.#checks.aarch64-darwin.unit-overlay' \
  '.#checks.aarch64-darwin.integration-configurations-eval'
