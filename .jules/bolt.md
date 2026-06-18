## 2024-06-18 - Avoid spawning subprocesses in loops or for simple extractions
**Learning:** Using `grep`, `awk`, `head`, or `sed` for simple text extraction when the text is already stored in a bash variable creates unnecessary process forking overhead.
**Action:** Use native bash regex `[[ "$var" =~ $re ]]` (storing the regex in a variable first for macOS/Bash 3.2 compatibility) to extract substrings directly into `${BASH_REMATCH}`.
