## 2024-06-25 - Avoid Sub-Process Loops in Bash
**Learning:** Shell scripts spawning a subprocess (e.g., `jq`) inside a Bash loop introduces significant performance overhead, especially in CI environments or script automation like `au_latest_npm`.
**Action:** When filtering or iterating over structured data, push the iteration natively into tools like `jq` using `map` and `select` over an array to avoid repeating expensive process instantiations.
