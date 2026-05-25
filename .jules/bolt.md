## 2025-02-18 - Safe Parallel File Modifications
**Learning:** When parallelizing file modifications in bash scripts (like `au_set_block_hash`), writing to the same file from concurrent background jobs causes race conditions and corrupted files.
**Action:** When using bash background jobs (`&`) to parallelize I/O heavy tasks like `au_prefetch_sri`, always fetch the output into temporary files first (e.g. inside a `mktemp -d` directory). Wait for all jobs to finish (`wait "$pid"`), then sequentially read those files to apply changes to the main source file safely.
