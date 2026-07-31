## 2025-02-12 - Bash RegEx vs Subprocess Performance
**Learning:** Native bash regex (`=~`) coupled with `${BASH_REMATCH[]}` runs orders of magnitude faster (0.074s vs 5.229s) than using multiple subprocess pipelines (like `grep` + `awk`) inside a tight loop when parsing strings already in memory.
**Action:** Replace `grep ... | awk ...` in loops when strings are stored in variables with native `=~` bash checks.
