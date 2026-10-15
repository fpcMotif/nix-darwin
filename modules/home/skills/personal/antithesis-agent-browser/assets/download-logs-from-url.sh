#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_JS="${SCRIPT_DIR}/antithesis-agent-browser.js"

URL=""
OUTPUT=""
FORMAT="json"

exit_with_usage() {
  echo "Usage: download-logs-from-url.sh --url <LOGS_URL> --output <PATH> [--format json|txt|csv]" >&2
  exit 4
}

die() {
  local code=$1 message=$2
  echo "Error: $message" >&2
  exit "$code"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)      URL="$2"; shift 2 ;;
    --output)   OUTPUT="$2"; shift 2 ;;
    --format)   FORMAT="$2"; shift 2 ;;
    -h|--help)  exit_with_usage ;;
    *)          echo "Unknown option: $1" >&2; exit_with_usage ;;
  esac
done

[[ -z "$URL" ]] && { echo "Error: --url is required" >&2; exit_with_usage; }
[[ -z "$OUTPUT" ]] && { echo "Error: --output is required" >&2; exit_with_usage; }

case "$FORMAT" in
  json|txt|csv) ;;
  *) echo "Error: --format must be json, txt, or csv" >&2; exit_with_usage ;;
esac

mkdir -p "$(dirname "$OUTPUT")"

SESSION="download-logs-$(date +%s)-$$"
TMPFILE=$(mktemp)

browser() { agent-browser --session "$SESSION" "$@"; }

cleanup() {
  browser close >/dev/null 2>&1 || true
  rm -f "$TMPFILE"
}
trap cleanup EXIT

echo "Opening log URL..." >&2
browser --session-name antithesis open "$URL" >/dev/null 2>&1 || die 3 "failed to open URL"

browser wait --load networkidle >/dev/null 2>&1 || true
CURRENT_URL=$(browser get url 2>/dev/null || echo "unknown")
[[ "$CURRENT_URL" == */search* ]] || die 2 "did not land on logs page (at: $CURRENT_URL)"

echo "Injecting runtime..." >&2
browser eval --stdin <"$RUNTIME_JS" >/dev/null 2>&1 || die 3 "failed to inject agent-browser runtime"

echo "Waiting for logs to load..." >&2
browser eval "window.__antithesisAgentBrowser.logs.waitForReady()" >/dev/null 2>&1 \
  || die 2 "log viewer did not become ready"

echo "Preparing download ($FORMAT)..." >&2
browser eval "window.__antithesisAgentBrowser.logs.prepareDownload('${FORMAT}', 0)" >/dev/null 2>&1 \
  || die 3 "prepareDownload failed"

# A failed or partial download must never replace an existing OUTPUT.
echo "Downloading..." >&2
browser download 'a.sequence_printer_menu_button[data-ab-dl]' "$TMPFILE" >/dev/null 2>&1 \
  || die 3 "download failed"
[[ -s "$TMPFILE" ]] || die 3 "downloaded file is empty"

# Annotation belongs to antithesis-debug/assets/process-logs.py, so this skill keeps the raw log.
mv "$TMPFILE" "$OUTPUT"

echo "Done: $OUTPUT" >&2
