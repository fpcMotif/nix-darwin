## 2025-07-25 - Native bash regex instead of grep/awk
**Learning:** In bash scripts, spawning a subprocess like \`grep -E ... | head -1\` and \`awk '{print $2}'\` to extract values is slow compared to native bash string matching. This is especially true when parsing a multiline variable that is already in memory.
**Action:** Use native bash regex (\`=~\`) combined with \`${BASH_REMATCH[]}\` for extracting data from small-to-medium multiline variables instead of pipelining to grep/awk. Avoid this for very large files to avoid memory overhead of slurping the whole file.
