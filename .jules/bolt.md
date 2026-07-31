## 2024-06-07 - Native Bash Regex in Loops
**Learning:** Using subprocesses like `grep`, `head`, and `awk` inside bash loops is a severe performance bottleneck. Processing a small string 100 times with subprocesses took ~7.8s, while native bash regex `=~` took ~0.1s.
**Action:** To reduce performance overhead in Bash scripts, avoid spawning subprocesses inside loops. Push iteration and filtering logic natively into bash, making sure to assign the regex to a variable first for macOS compatibility.
