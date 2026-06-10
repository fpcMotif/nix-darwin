## 2024-05-24 - Avoid micro-optimizations that hurt readability

**Learning:** While replacing `grep | head | sed` with a complex, native `jq` query (using `select`, `test`, `capture`) slightly reduces CPU cycles and process forks, it is an anti-pattern for one-off, network-bound update scripts. The network call (`curl`) dwarfs any local execution time, meaning the "optimization" yields zero measurable real-world impact while significantly degrading code readability for future maintainers.

**Action:** Only optimize code where the bottleneck is proven to be local execution time. For scripts dominated by I/O or network wait times, prioritize readability over saving milliseconds or a few process forks.
