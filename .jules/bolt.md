## 2024-06-19 - Subprocess overhead for regex extraction
**Learning:** Piping strings already loaded in memory to `grep`, `head`, and `sed` to extract regex matches has huge subprocess overhead compared to using pure Bash regex matching (`=~`), which resulted in a >10x speedup in `au_extract_got_hash`.
**Action:** When working with strings already loaded in a Bash variable, use pure Bash regex matching (`[[ "$var" =~ $re ]]`) to extract substrings instead of spawning external binaries. Assign the regex to a variable first to ensure macOS compatibility.
