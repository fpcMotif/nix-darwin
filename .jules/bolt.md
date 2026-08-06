## 2024-05-24 - Bash subprocess overhead elimination
**Learning:** In Bash scripts handling multi-line strings or frequent pattern matching in loops, piping to `grep -q` or `awk` creates significant subshell and process fork overhead.
**Action:** Replace `echo "$var" | grep -qF "$needle"` with native Bash glob matching `[[ "$var" == *"$needle"* ]]` to significantly reduce execution time. Replace `awk '{print $2}'` with native regex capture `${BASH_REMATCH[]}`.
