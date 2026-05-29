
## 2024-05-28 - Minimize Bash Subprocess Overhead with Native jq Filtering
**Learning:** In shell scripts, spawning subprocesses (like `jq`) multiple times inside Bash loops (e.g., iterating through an array of preferred distribution tags) incurs significant overhead and reduces script performance.
**Action:** Push iteration and filtering logic natively into a single `jq` invocation using arrays, `map`, and `select` instead of looping in Bash. This minimizes subprocess spawning and greatly speeds up operations.

## 2024-05-28 - jq has() checks presence, not validity
**Learning:** Using `has($key)` in `jq` checks for key existence, even if the value is `""` or `null`. In the `au_latest_npm` function, checking only key presence caused the parser to stop at a tag with an empty string or null instead of falling through to the next valid tag. This creates a behavior regression.
**Action:** When filtering objects where null/empty string values are considered invalid, avoid `has($key)`. Instead, directly evaluate the value using `($obj[$key] and $obj[$key] != "" and $obj[$key] != null)` to ensure both presence and validity.
