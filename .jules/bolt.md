## 2024-05-24 - Bash subprocess pipeline overhead
**Learning:** Parsing strings via pipelines (`printf | grep | awk`) in Bash loops causes significant fork/exec overhead (~70x slower for native regex and parameter expansion).
**Action:** Replace subprocess pipelines with native Bash features: `[[ "$var" == *"$needle"* ]]` for contains, `[[ "$var" =~ regex ]]` with `${BASH_REMATCH[]}` for extraction, and `${var,,}` for case-insensitive matching.

## 2024-05-24 - Mission Boundary Enforcement
**Learning:** Fixing unrelated upstream Nix build failures (like `swift` or `openapv` on Linux CI) or hash mismatches for rolling canary assets (like `bun-canary-bin`) is explicitly strictly forbidden during focused performance optimization missions. The previous CI failure was caused by evaluating a macOS-only package on Linux (which was in scope as my own modification triggered the evaluation failure), but these new failures are pre-existing out-of-scope upstream build issues.
**Action:** Do not attempt to fix or workaround unrelated CI breakages when they fall outside the strict scope of the current task.
