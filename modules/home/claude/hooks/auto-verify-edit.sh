#!/bin/bash
command -v zigdiff >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[ -z "$CMD" ] && exit 0
if echo "$CMD" | grep -qE '(zigpatch|zigcreate)' && ! echo "$CMD" | grep -qE '(zigpatch|zigcreate)[[:space:]]+(pipe|--undo|--help|-h)'; then
  FILE=$(echo "$CMD" | awk '{for(i=1;i<=NF;i++){if($i=="zigpatch"||$i=="zigcreate"){for(j=i+1;j<=NF;j++){if(substr($j,1,1)!="-"){print $j;exit}}}}}')
  [ -n "$FILE" ] && [ -f "$FILE" ] && zigdiff "$FILE" >&2 2>&1
fi
exit 0
