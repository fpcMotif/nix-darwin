## 2025-02-18 - Optimize Hash Extraction with Native Bash Regex
**Learning:** In Bash scripts, using external commands like `grep`, `head`, and `sed` to extract data from a variable (which is already loaded in memory) introduces significant subprocess overhead.
**Action:** When extracting or parsing strings already in variables in Bash, prefer using native bash regex (`=~`) and `${BASH_REMATCH[]}` to significantly reduce execution time and subprocess spawn count.
