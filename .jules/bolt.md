## 2024-06-17 - Optimize pmset parsing loop in verify-macos-settings.sh
**Learning:** Parsing multiline string variables inside loops using subprocesses (`printf | grep | head`, `awk`) significantly degrades performance in Bash scripts.
**Action:** Use native Bash regex matching (`=~` with `BASH_REMATCH`) against the in-memory string variable, ensuring regex patterns are assigned to a separate variable first for macOS Bash 3.2 compatibility.
