#!/bin/bash
command -v zigmemo >/dev/null 2>&1 || exit 0
CONTEXT=$(zigmemo context 2>/dev/null)
[ -n "$CONTEXT" ] && echo "$CONTEXT"
exit 0
