## 2024-07-18 - Native Bash regex for strings in memory
**Learning:** Piping variables already loaded into memory to external tools like `grep`, `head`, and `sed` adds significant subprocess overhead in Bash scripts.
**Action:** Use native Bash regex `[[ $var =~ $re ]]` and `${BASH_REMATCH[]}` to extract patterns from in-memory strings, but remember to assign the regex to a variable first for macOS Bash 3.2 compatibility.
