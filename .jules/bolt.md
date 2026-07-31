## 2024-06-01 - Performance pattern for shell scripts
**Learning:** Shell script sub-processes can be a bottleneck. For `jq`, chaining loops and filtering logic into a single query is significantly more efficient than spawning a sub-shell process multiple times inside a Bash loop.
**Action:** When filtering or transforming JSON inside loops, rewrite to use single `jq` invocation where arrays, `map`, and `select` carry the filtering logic.

## 2024-06-01 - Avoid subprocess overhead in Bash loops and functions
**Learning:** Parsing strings with utilities like `grep`, `awk`, and `head` inside frequently executed Bash loops or functions incurs significant performance overhead due to spawning multiple sub-shell processes.
**Action:** Use Bash built-in features such as regular expression matching (`[[ "$string" =~ $regex ]]`) and glob matching (`[[ "$string" == *"$substring"* ]]`) to perform string checks and extractions natively without spawning external processes.
