## 2024-05-18 - Optimizing Bash Regex Variables

**Learning:** In Bash scripts, the `local` keyword can only be used inside a function. Using `local variable_name=...` at the top level of a script or inside a top-level loop causes a fatal syntax error (`bash: local: can only be used in a function`).

**Action:** When replacing external pipelines (`grep`/`awk`) with native Bash matching (`=~`) in top-level loops, declare and assign variables without the `local` keyword to avoid breaking the script.
