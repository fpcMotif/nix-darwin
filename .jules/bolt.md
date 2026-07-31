
## 2024-05-24 - jq Regex Optimization Avoids macOS sed Traps
**Learning:** Replacing shell pipelines like `jq | grep | head | sed` with a single native `jq` invocation (`jq -r '[.[] | select(test(...)) | capture(...) | .v] | .[0]'`) is highly effective. Not only does it reduce subprocess spawn overhead, it actively prevents cross-platform bugs because BSD `sed` (default on macOS) throws syntax errors on common GNU `sed` inline tricks like `s/.../.../p; q;`.
**Action:** When parsing JSON in shell scripts, push all filtering and regex extraction into `jq` natively rather than piping to `grep` or `sed`. If `sed` must be used for performance, avoid semicolons inside the curly braces of address matches (e.g., `/pattern/{s/.../.../p;q;}`) to maintain macOS compatibility.
