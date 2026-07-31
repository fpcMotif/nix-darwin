## 2024-06-05 - Bash loops vs grep performance
**Learning:** In Bash scripts, replacing compiled C binaries (like `grep` or `awk`) with a pure Bash `while read` loop for file processing results in a severe performance downgrade. Native Bash regex (`=~`) is only a performance win when used on strings already loaded into memory.
**Action:** Never replace `grep` or `awk` with a `while read` loop for processing files. Only use `=~` for strings already in variables.
