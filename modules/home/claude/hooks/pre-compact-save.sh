#!/bin/bash
command -v zigmemo >/dev/null 2>&1 || exit 0
PLAN=$(zigmemo plan --status 2>/dev/null)
if [ -n "$PLAN" ] && ! echo "$PLAN" | grep -q 'no plan'; then
  zigmemo store "[pre-compact] Plan: $PLAN" --tag compact-save 2>/dev/null
fi
ERRORS=$(zigmemo errors 2>/dev/null)
if [ -n "$ERRORS" ] && ! echo "$ERRORS" | grep -q 'no errors'; then
  zigmemo store "[pre-compact] Errors: $ERRORS" --tag compact-save 2>/dev/null
fi
exit 0
