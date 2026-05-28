
## 2024-05-28 - Minimize Bash Subprocess Overhead with Native jq Filtering
**Learning:** In shell scripts, spawning subprocesses (like `jq`) multiple times inside Bash loops (e.g., iterating through an array of preferred distribution tags) incurs significant overhead and reduces script performance.
**Action:** Push iteration and filtering logic natively into a single `jq` invocation using arrays, `map`, and `select` instead of looping in Bash. This minimizes subprocess spawning and greatly speeds up operations.
