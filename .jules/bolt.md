## 2024-05-18 - Optimize in-memory string parsing in Bash
**Learning:** Parsing large in-memory strings (like build logs) via standard out piping (`grep | head | sed`) causes significant overhead due to subprocess creation. Native Bash regex (`=~`) with `BASH_REMATCH` avoids this overhead and provides massive speedups for extraction.
**Action:** When extracting data from strings already held in variables in Bash, use native `=~` regex with `BASH_REMATCH` arrays instead of spawning subprocesses.
