## 2024-05-18 - Native Bash Regex Optimization
**Learning:** Using native Bash regex (=~) on strings already loaded into memory avoids severe subprocess overhead (e.g., piping to grep, head, and sed). Note that for macOS Bash 3.2 compatibility, regex patterns must be assigned to a variable before being used in the conditional.
**Action:** Prioritize using =~ and ${BASH_REMATCH[]} over subprocess pipelines for parsing in-memory strings in Bash scripts.
