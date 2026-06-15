## $(date +%Y-%m-%d) - Bash 3.2 regex matching for multiline strings
**Learning:** In Bash (especially macOS Bash 3.2), the `=~` regex operator's `^` anchor matches the start of the entire string, not the start of individual lines within a multiline variable. Using `grep` and `head` inside loops to parse multiline strings incurs significant subprocess overhead.
**Action:** To match the start of a line or a word boundary natively without spawning subprocesses like `grep`, use patterns like `([[:space:]]|^)` instead of `^`.
