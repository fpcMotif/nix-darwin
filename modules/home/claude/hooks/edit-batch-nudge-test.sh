#!/bin/bash
# Table test for edit-batch-nudge.sh over synthetic transcripts.
# Run: bash edit-batch-nudge-test.sh [path/to/edit-batch-nudge.sh]
HOOK=${1:-$(dirname "$0")/edit-batch-nudge.sh}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP"
fail=0; n=0

# line ROLE ID TOOLS... : one transcript line. ROLE=a(ssistant)|p(rompt)|r(esult). TOOLS are tool_use names.
line() {
  role=$1; id=$2; shift 2
  case "$role" in
    a) jq -cn --arg id "$id" --args '{type:"assistant",message:{id:$id,content:[$ARGS.positional[] | {type:"tool_use",name:.,id:("t"+.)}]}}' "$@";;
    p) jq -cn --arg id "$id" '{type:"user",uuid:$id,message:{content:"hello"}}';;
    r) jq -cn --arg id "$id" '{type:"user",uuid:$id,message:{content:[{type:"tool_result",tool_use_id:"tEdit",content:"ok"}]}}';;
  esac
}
# check WANT NAME TRANSCRIPT [SESSION] [TOOL_USE_ID]: WANT is the nudged count or none.
check() {
  want=$1; name=$2; n=$((n + 1)); t="$TMP/$n.jsonl"; printf '%s\n' "$3" > "$t"
  out=$(jq -cn --arg t "$t" --arg s "${4:-s$n}" --arg u "${5:-tnone}" '{tool_name:"Edit",transcript_path:$t,session_id:$s,tool_use_id:$u}' | bash "$HOOK")
  got=none; case "$out" in *batch-nudge:*) got=$(printf '%s' "$out" | sed -E 's/.*batch-nudge: ([0-9]+).*/\1/');; esac
  [ "$got" != "$want" ] && { fail=$((fail + 1)); printf 'FAIL %s: want=%s got=%s\n  %s\n' "$name" "$want" "$got" "$out"; }
}

# The current message is not written yet: previous turns decide, this one is presumed solo.
check 2    "one previous solo Edit turn"        "$(line p u1; line a m1 Edit; line r u2)"
check 3    "two previous solo Edit turns"       "$(line p u1; line a m1 Edit; line r u2; line a m2 Edit; line r u3)"
check none "no previous tool turn"              "$(line p u1)"
check none "previous message batched two Edits" "$(line p u1; line a m1 Edit Edit; line r u2; line r u3)"
check none "previous message split by streaming" "$(line p u1; line a m1 Edit; line r u2; line a m1 Edit; line r u3)"
check none "previous turn was Bash"             "$(line p u1; line a m1 Bash; line r u2)"
check none "previous turn was Read and Edit"    "$(line p u1; line a m1 Edit; line r u2; line a m2 Read Edit; line r u3; line r u4)"
check none "human prompt after the solo Edit"   "$(line p u1; line a m1 Edit; line r u2; line p u3)"
check 3    "run counted after a Bash break"     "$(line p u1; line a m1 Edit; line r u2; line a m2 Bash; line r u3; line a m3 Edit; line r u4; line a m4 Edit; line r u5)"
# The current message is already written (its tool_use_id is in the tail): counted, not presumed.
check 2    "current solo Edit already written"  "$(line p u1; line a m1 Edit; line r u2; line a m2 Edit)" s-written tEdit
# Same session, second fire inside 3 s: same batch, silent.
check 2    "first Edit of a batch"              "$(line p u1; line a m1 Edit; line r u2)" s-batch
check none "second Edit of the same batch"      "$(line p u1; line a m1 Edit; line r u2)" s-batch

printf '%s/%s cases passed\n' "$((n - fail))" "$n"
[ "$fail" -eq 0 ]
