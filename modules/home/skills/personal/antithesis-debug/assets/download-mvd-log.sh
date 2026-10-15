#!/usr/bin/env bash
#
# download-mvd-log.sh — Download the events log from a Multiverse Debugger
# (MVD) report page via agent-browser, then (optionally) annotate it with
# active-faults metadata using process-logs.py.
#
# Usage:
#   download-mvd-log.sh --url <DEBUG_URL> -o PATH [--format json|txt|csv] [--raw]
#
# Defaults: --format json. Annotation is applied for json output unless --raw
# is passed. txt and csv outputs are written verbatim.
#
# Requires: agent-browser, jq, python3 (for json post-processing).
#
# The script:
#   1. Opens the debugging-session URL with shared antithesis auth.
#   2. Verifies the URL is on a /debugging-session/... path.
#   3. Injects assets/antithesis-debug.js, calls
#      window.__antithesisDebug.simplified.prepareLogDownload(format) to
#      locate the events.<fmt> anchor, force the shadow-root menu visible,
#      and tag the link.
#   4. Captures the click via `agent-browser download <selector> <tmp>`.
#   5. For json: pipes through process-logs.py to add vtime_seconds and
#      active_faults annotations. For txt/csv or --raw: moves the temp file
#      to OUTPUT verbatim.
#
# Exit codes:
#   0  success
#   2  did not land on a debugging-session page (auth or wrong URL)
#   3  download or processing error
#   4  usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_JS="${SCRIPT_DIR}/antithesis-debug.js"
PROCESS_LOGS="${SCRIPT_DIR}/process-logs.py"

# The header comment is the usage text, up to its first blank line.
exit_with_usage() {
  sed -n '3,/^$/p' "${BASH_SOURCE[0]}" | sed -E 's/^# ?//' >&2
  exit 4
}

die() {
  local code=$1 message=$2
  echo "Error: $message" >&2
  exit "$code"
}

URL=""
OUTPUT=""
FORMAT="json"
RAW=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)         URL="$2"; shift 2 ;;
    -o|--output)   OUTPUT="$2"; shift 2 ;;
    --format)      FORMAT="$2"; shift 2 ;;
    --raw)         RAW=1; shift ;;
    -h|--help)     exit_with_usage ;;
    *)             echo "Error: unknown option: $1" >&2; exit_with_usage ;;
  esac
done

[[ -z "$URL" ]] && { echo "Error: --url is required" >&2; exit_with_usage; }
[[ -z "$OUTPUT" ]] && { echo "Error: -o/--output is required" >&2; exit_with_usage; }

case "$FORMAT" in
  json|txt|csv) ;;
  *) echo "Error: --format must be json, txt, or csv" >&2; exit_with_usage ;;
esac

for tool in agent-browser jq python3; do
  command -v "$tool" >/dev/null 2>&1 || die 4 "$tool not found in PATH"
done

mkdir -p "$(dirname "$OUTPUT")"

SESSION="antithesis-debug-dl-$(date +%s)-$$"
TMPFILE=$(mktemp)

browser() { agent-browser --session "$SESSION" "$@"; }

cleanup() {
  browser close >/dev/null 2>&1 || true
  rm -f "$TMPFILE"
}
trap cleanup EXIT

wait_for_events_log_panel() {
  local deadline=$(( $(date +%s) + 30 )) ready
  while :; do
    ready=$(browser eval "window.__antithesisDebug.simplified.eventsLogReady('${FORMAT}')" 2>/dev/null | tail -1)
    [[ "$ready" == "true" ]] && return
    [[ $(date +%s) -ge $deadline ]] && die 3 "events log panel did not render within 30s"
    sleep 1
  done
}

echo "Opening MVD URL..." >&2
browser --session-name antithesis open "$URL" >/dev/null 2>&1 || die 3 "failed to open URL"

browser wait --load networkidle >/dev/null 2>&1 || true
CURRENT_URL=$(browser get url 2>/dev/null || echo "unknown")
if [[ "$CURRENT_URL" != *"/debugging-session/"* ]]; then
  echo "Error: did not land on a debugging-session page (at: $CURRENT_URL)" >&2
  echo "If redirected to a login page, authenticate first using the antithesis-agent-browser skill's setup-auth flow." >&2
  exit 2
fi

echo "Injecting runtime..." >&2
browser eval --stdin <"$RUNTIME_JS" >/dev/null 2>&1 || die 3 "failed to inject debug runtime"

echo "Waiting for simplified view to be ready..." >&2
browser eval 'window.__antithesisDebug.simplified.waitForReady()' >/dev/null 2>&1 \
  || die 3 "simplified view did not become ready"

echo "Waiting for events log panel to render..." >&2
wait_for_events_log_panel

echo "Preparing download (format: $FORMAT)..." >&2
PREPARE_RESULT=$(browser eval "window.__antithesisDebug.simplified.prepareLogDownload('${FORMAT}')" 2>&1)
if echo "$PREPARE_RESULT" | jq -e '.error' >/dev/null 2>&1; then
  die 3 "prepareLogDownload failed: $(echo "$PREPARE_RESULT" | jq -r '.error')"
fi

echo "Downloading..." >&2
browser download 'a.sequence_printer_menu_button[data-mvd-dl]' "$TMPFILE" >/dev/null 2>&1 \
  || die 3 "download failed"
[[ -s "$TMPFILE" ]] || die 3 "downloaded file is empty"

if [[ "$FORMAT" == "json" && "$RAW" -eq 0 ]]; then
  echo "Annotating logs with vtime_seconds and active_faults..." >&2
  python3 "$PROCESS_LOGS" "$TMPFILE" -o "$OUTPUT" || die 3 "process-logs.py failed"
else
  mv "$TMPFILE" "$OUTPUT"
fi

echo "Wrote: $OUTPUT" >&2
