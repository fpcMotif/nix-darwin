## 2024-06-02 - Bash native regex optimization
**Learning:** Using `printf | grep | head` and `awk` inside bash loops is a huge performance bottleneck because it repeatedly spawns subprocesses.
**Action:** Instead, push iteration and string extraction to native Bash by constructing regex patterns in an intermediate variable (to avoid macOS Bash 3.2 parsing errors) and matching via `[[ "$var" =~ $re ]]` using `${BASH_REMATCH}`.
