## 2024-08-02 - Optimize Bash string matching by replacing subprocesses
**Learning:** Replacing subprocess pipelines (like `echo "$var" | grep -qF "$needle"`) with native bash string matching (like `[[ "$var" == *"$needle"* ]]`) and native regex matching (`=~`) significantly reduces execution overhead.
**Action:** When working in bash, especially inside loops or heavily reused functions, use native bash operators instead of piping strings to `grep` or `awk` to avoid subshell and subprocess fork overhead.
