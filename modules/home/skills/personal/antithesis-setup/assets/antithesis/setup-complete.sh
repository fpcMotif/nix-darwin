#!/usr/bin/env bash
set -euo pipefail

# Antithesis sets ANTITHESIS_OUTPUT_DIR in every run, so an unset value means a local run.
if [[ -n "${ANTITHESIS_OUTPUT_DIR:-}" ]]; then
  OUTPUT_PATH="${ANTITHESIS_OUTPUT_DIR}/sdk.jsonl"
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  echo "Running in Antithesis, emitting setup_complete to ${OUTPUT_PATH}"
  echo '{"antithesis_setup":{"status":"complete","details":{"message":"ready to go"}}}' >> "${OUTPUT_PATH}"
else
  echo "\$ANTITHESIS_OUTPUT_DIR is unset, not emitting setup-complete"
fi
