## 2024-05-24 - Bash subprocess pipeline overhead
**Learning:** Parsing strings via pipelines (`printf | grep | awk`) in Bash loops causes significant fork/exec overhead (~70x slower for native regex and parameter expansion).
**Action:** Replace subprocess pipelines with native Bash features: `[[ "$var" == *"$needle"* ]]` for contains, `[[ "$var" =~ regex ]]` with `${BASH_REMATCH[]}` for extraction, and `${var,,}` for case-insensitive matching.
