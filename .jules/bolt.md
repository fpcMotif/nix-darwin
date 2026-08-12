## 2024-08-12 - Native Bash Globbing > Subprocess Pipelines
**Learning:** Replacing subprocess pipelines like `echo "$var" | grep -qF "$needle"` with native Bash glob matching `[[ "$var" == *"$needle"* ]]` significantly reduces execution time by avoiding subshell forks, achieving a ~260x speedup in isolated testing.
**Action:** Always prefer native Bash string manipulation and globbing constructs over spawning external processes like `grep` for simple substring checks within loops or frequently executed scripts.
